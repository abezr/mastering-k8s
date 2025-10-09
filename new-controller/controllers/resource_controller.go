// controllers/resource_controller.go
package controllers

import (
	"context"
	"time"

	newv1 "github.com/abezr/mastering-k8s/new-controller/api/v1alpha1"

	"github.com/prometheus/client_golang/prometheus"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/metrics"
)

var (
	// Metrics definitions
	reconcileTotalCounter = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "controller_reconcile_total",
			Help: "Total number of reconciliation attempts",
		},
		[]string{"controller", "result"},
	)

	reconcileDurationHistogram = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "controller_reconcile_duration_seconds",
			Help:    "Time spent reconciling resources",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"controller"},
	)

	reconcileErrorsCounter = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "controller_reconcile_errors_total",
			Help: "Total number of reconciliation errors",
		},
		[]string{"controller", "error_type"},
	)
)

type NewResourceReconciler struct {
	client.Client
}

func (r *NewResourceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	// Start metrics recording
	start := time.Now()
	controllerName := "NewResource"
	reconcileTotalCounter.WithLabelValues(controllerName, "started").Inc()
	defer func() {
		duration := time.Since(start).Seconds()
		reconcileDurationHistogram.WithLabelValues(controllerName).Observe(duration)
	}()

	var resource newv1.NewResource
	if err := r.Get(ctx, req.NamespacedName, &resource); err != nil {
		if client.IgnoreNotFound(err) == nil {
			// Resource not found - normal case
			reconcileTotalCounter.WithLabelValues(controllerName, "not_found").Inc()
			logger.Info("Resource not found, ignoring", "name", req.NamespacedName)
			return ctrl.Result{}, nil
		}
		// Actual error
		reconcileTotalCounter.WithLabelValues(controllerName, "error").Inc()
		reconcileErrorsCounter.WithLabelValues(controllerName, "get_resource").Inc()
		logger.Error(err, "Failed to get resource", "name", req.NamespacedName)
		return ctrl.Result{}, err
	}

	logger.Info("Reconciling", "name", resource.Name, "namespace", resource.Namespace)

	// Set the resource status to ready
	resource.Status.Ready = true

	logger.Info("Attempting to update resource status", "name", resource.Name, "namespace", resource.Namespace, "ready", resource.Status.Ready)

	// Update the status
	if err := r.Status().Update(ctx, &resource); err != nil {
		reconcileTotalCounter.WithLabelValues(controllerName, "error").Inc()
		reconcileErrorsCounter.WithLabelValues(controllerName, "status_update").Inc()
		logger.Error(err, "Failed to update resource status", "name", resource.Name, "namespace", resource.Namespace)
		return ctrl.Result{}, err
	}

	logger.Info("Successfully reconciled resource", "name", resource.Name, "namespace", resource.Namespace, "ready", resource.Status.Ready)

	// Success
	reconcileTotalCounter.WithLabelValues(controllerName, "success").Inc()
	return ctrl.Result{}, nil
}

func (r *NewResourceReconciler) SetupWithManager(mgr ctrl.Manager) error {
	// Register metrics
	if err := metrics.Registry.Register(reconcileTotalCounter); err != nil {
		return err
	}
	if err := metrics.Registry.Register(reconcileDurationHistogram); err != nil {
		return err
	}
	if err := metrics.Registry.Register(reconcileErrorsCounter); err != nil {
		return err
	}

	return ctrl.NewControllerManagedBy(mgr).
		For(&newv1.NewResource{}).
		Complete(r)
}
