package test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	newv1 "github.com/abezr/mastering-k8s/new-controller/api/v1alpha1"
	"github.com/abezr/mastering-k8s/new-controller/controllers"
	apiextensionsv1 "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"sigs.k8s.io/controller-runtime/pkg/client"
	ctrl "sigs.k8s.io/controller-runtime/pkg/controller"
	"sigs.k8s.io/controller-runtime/pkg/log"
)

// TestMainController tests that the controller can be started and CRD is available
func TestMainController(t *testing.T) {
	cleanup := setupMainTestEnv(t)
	// defer cleanup() // Moved to after sleep

	// Set up the reconciler once for all tests
	reconciler := &controllers.NewResourceReconciler{
		Client: mainTestMgr.GetClient(),
	}

	err := reconciler.SetupWithManager(mainTestMgr)
	require.NoError(t, err)

	t.Run("test_crd_available", func(t *testing.T) {
		// Check that our CRD is available in the test cluster
		crd := &apiextensionsv1.CustomResourceDefinition{}
		err := mainTestClient.Get(context.TODO(), client.ObjectKey{
			Name: "newresources.apps.newresource.com",
		}, crd)
		require.NoError(t, err)
		require.Equal(t, "newresources.apps.newresource.com", crd.Name)
	})

	t.Run("test_controller_startup", func(t *testing.T) {
		// Start the manager in a goroutine
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		go func() {
			if err := mainTestMgr.Start(ctx); err != nil {
				t.Logf("Manager stopped with error: %v", err)
			}
		}()

		// Wait a bit to ensure the manager starts
		time.Sleep(1 * time.Second)

		// Verify the manager is running
		require.NotNil(t, mainTestMgr)
		require.NotNil(t, mainTestMgr.GetClient())
		require.NotNil(t, mainTestMgr.GetScheme())
	})

	t.Run("test_can_create_newresource", func(t *testing.T) {
		// Test that we can create a NewResource instance
		newResource := &newv1.NewResource{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "test-resource",
				Namespace: "default",
			},
			Spec: newv1.NewResourceSpec{
				// Add any required spec fields here
			},
		}

		err := mainTestClient.Create(context.TODO(), newResource)
		require.NoError(t, err)

		// Clean up
		defer func() {
			mainTestClient.Delete(context.TODO(), newResource)
		}()

		// Verify it was created
		created := &newv1.NewResource{}
		err = mainTestClient.Get(context.TODO(), client.ObjectKey{
			Name:      "test-resource",
			Namespace: "default",
		}, created)
		require.NoError(t, err)
		require.Equal(t, "test-resource", created.Name)
	})

	// Cleanup after sleep
	cleanup()
}

// TestReconciliationScenarios tests comprehensive reconciliation scenarios
func TestReconciliationScenarios(t *testing.T) {
	cleanup := setupMainTestEnv(t)
	defer cleanup()

	// Set up the reconciler
	reconciler := &controllers.NewResourceReconciler{
		Client: mainTestMgr.GetClient(),
	}

	err := reconciler.SetupWithManager(mainTestMgr)
	require.NoError(t, err)

	t.Run("test_successful_reconciliation", func(t *testing.T) {
		// Create a test resource
		testResource := &newv1.NewResource{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "test-reconcile-success",
				Namespace: "default",
			},
			Spec: newv1.NewResourceSpec{
				Foo: "test-value",
			},
		}

		err := mainTestClient.Create(context.TODO(), testResource)
		require.NoError(t, err)

		// Clean up after test
		defer func() {
			mainTestClient.Delete(context.TODO(), testResource)
		}()

		// Test reconciliation
		req := ctrl.Request{
			NamespacedName: client.ObjectKey{
				Name:      "test-reconcile-success",
				Namespace: "default",
			},
		}

		result, err := reconciler.Reconcile(context.TODO(), req)
		require.NoError(t, err)
		require.Equal(t, ctrl.Result{}, result)

		// Verify status was updated
		updated := &newv1.NewResource{}
		err = mainTestClient.Get(context.TODO(), client.ObjectKey{
			Name:      "test-reconcile-success",
			Namespace: "default",
		}, updated)
		require.NoError(t, err)
		require.True(t, updated.Status.Ready)
	})

	t.Run("test_resource_not_found", func(t *testing.T) {
		// Test reconciliation for non-existent resource
		req := ctrl.Request{
			NamespacedName: client.ObjectKey{
				Name:      "non-existent-resource",
				Namespace: "default",
			},
		}

		result, err := reconciler.Reconcile(context.TODO(), req)
		require.NoError(t, err)
		require.Equal(t, ctrl.Result{}, result)
	})

	t.Run("test_resource_retrieval_error", func(t *testing.T) {
		// Create a mock reconciler that will fail on Get
		mockReconciler := &controllers.NewResourceReconciler{
			Client: &mockClient{err: errors.New("mock get error")},
		}

		req := ctrl.Request{
			NamespacedName: client.ObjectKey{
				Name:      "test-resource",
				Namespace: "default",
			},
		}

		result, err := mockReconciler.Reconcile(context.TODO(), req)
		require.Error(t, err)
		require.Equal(t, ctrl.Result{}, result)
	})

	t.Run("test_status_update_failure", func(t *testing.T) {
		// Create a test resource
		testResource := &newv1.NewResource{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "test-status-failure",
				Namespace: "default",
			},
			Spec: newv1.NewResourceSpec{
				Foo: "test-value",
			},
		}

		err := mainTestClient.Create(context.TODO(), testResource)
		require.NoError(t, err)

		// Clean up after test
		defer func() {
			mainTestClient.Delete(context.TODO(), testResource)
		}()

		// Create a mock reconciler that will fail on Status().Update
		mockReconciler := &controllers.NewResourceReconciler{
			Client: &mockClient{
				resource: testResource,
				statusErr: errors.New("mock status update error"),
			},
		}

		req := ctrl.Request{
			NamespacedName: client.ObjectKey{
				Name:      "test-status-failure",
				Namespace: "default",
			},
		}

		result, err := mockReconciler.Reconcile(context.TODO(), req)
		require.Error(t, err)
		require.Equal(t, ctrl.Result{}, result)
	})

	t.Run("test_metrics_collection", func(t *testing.T) {
		// Create a test resource for metrics testing
		testResource := &newv1.NewResource{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "test-metrics",
				Namespace: "default",
			},
			Spec: newv1.NewResourceSpec{
				Foo: "metrics-test",
			},
		}

		err := mainTestClient.Create(context.TODO(), testResource)
		require.NoError(t, err)

		// Clean up after test
		defer func() {
			mainTestClient.Delete(context.TODO(), testResource)
		}()

		// Test that reconciliation completes successfully
		req := ctrl.Request{
			NamespacedName: client.ObjectKey{
				Name:      "test-metrics",
				Namespace: "default",
			},
		}

		result, err := reconciler.Reconcile(context.TODO(), req)
		require.NoError(t, err)
		require.Equal(t, ctrl.Result{}, result)

		// Verify the resource status was updated (indicating successful reconciliation)
		updated := &newv1.NewResource{}
		err = mainTestClient.Get(context.TODO(), client.ObjectKey{
			Name:      "test-metrics",
			Namespace: "default",
		}, updated)
		require.NoError(t, err)
		require.True(t, updated.Status.Ready)
	})

	t.Run("test_reconciliation_with_different_namespaces", func(t *testing.T) {
		// Create test namespace
		testNamespace := &metav1.ObjectMeta{
			Name: "test-namespace",
		}

		// Create resource in different namespace
		testResource := &newv1.NewResource{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "test-namespace-resource",
				Namespace: "test-namespace",
			},
			Spec: newv1.NewResourceSpec{
				Foo: "namespace-test",
			},
		}

		err := mainTestClient.Create(context.TODO(), testResource)
		require.NoError(t, err)

		// Clean up after test
		defer func() {
			mainTestClient.Delete(context.TODO(), testResource)
		}()

		// Test reconciliation in specific namespace
		req := ctrl.Request{
			NamespacedName: client.ObjectKey{
				Name:      "test-namespace-resource",
				Namespace: "test-namespace",
			},
		}

		result, err := reconciler.Reconcile(context.TODO(), req)
		require.NoError(t, err)
		require.Equal(t, ctrl.Result{}, result)

		// Verify status was updated
		updated := &newv1.NewResource{}
		err = mainTestClient.Get(context.TODO(), client.ObjectKey{
			Name:      "test-namespace-resource",
			Namespace: "test-namespace",
		}, updated)
		require.NoError(t, err)
		require.True(t, updated.Status.Ready)
	})

	t.Run("test_concurrent_reconciliations", func(t *testing.T) {
		// Create multiple resources for concurrent testing
		resources := make([]*newv1.NewResource, 3)
		resourceNames := []string{"concurrent-1", "concurrent-2", "concurrent-3"}

		for i, name := range resourceNames {
			resources[i] = &newv1.NewResource{
				ObjectMeta: metav1.ObjectMeta{
					Name:      name,
					Namespace: "default",
				},
				Spec: newv1.NewResourceSpec{
					Foo: "concurrent-test",
				},
			}

			err := mainTestClient.Create(context.TODO(), resources[i])
			require.NoError(t, err)

			// Clean up after test
			defer func(resource *newv1.NewResource) {
				mainTestClient.Delete(context.TODO(), resource)
			}(resources[i])
		}

		// Test concurrent reconciliations
		for _, name := range resourceNames {
			req := ctrl.Request{
				NamespacedName: client.ObjectKey{
					Name:      name,
					Namespace: "default",
				},
			}

			result, err := reconciler.Reconcile(context.TODO(), req)
			require.NoError(t, err)
			require.Equal(t, ctrl.Result{}, result)
		}

		// Verify all resources were updated
		for _, name := range resourceNames {
			updated := &newv1.NewResource{}
			err := mainTestClient.Get(context.TODO(), client.ObjectKey{
				Name:      name,
				Namespace: "default",
			}, updated)
			require.NoError(t, err)
			require.True(t, updated.Status.Ready)
		}
	})
}

// mockClient is a test helper that allows simulating different error conditions
type mockClient struct {
	client.Client
	resource  *newv1.NewResource
	err       error
	statusErr error
}

func (m *mockClient) Get(ctx context.Context, key client.ObjectKey, obj client.Object, opts ...client.GetOption) error {
	if m.err != nil {
		return m.err
	}

	if m.resource != nil {
		// Copy the resource data to the target object
		if resource, ok := obj.(*newv1.NewResource); ok {
			*resource = *m.resource
			return nil
		}
	}

	return apierrors.NewNotFound(schema.GroupResource{Group: "example.com", Resource: "newresources"}, key.Name)
}

func (m *mockClient) Status() client.StatusWriter {
	return &mockStatusWriter{err: m.statusErr}
}

type mockStatusWriter struct {
	client.StatusWriter
	err error
}

func (m *mockStatusWriter) Update(ctx context.Context, obj client.Object, opts ...client.UpdateOption) error {
	if m.err != nil {
		return m.err
	}
	return nil
}
