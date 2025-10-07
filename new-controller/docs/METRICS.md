# Metrics and Health Endpoints

This document explains the controller metrics, how to scrape them with Prometheus, and how to use health and readiness probes.

## Endpoints

- Metrics endpoint
  - Path: /metrics
  - Port: 8080
  - Format: Prometheus exposition
- Health endpoints
  - Liveness: /healthz on port 8081
  - Readiness: /readyz on port 8081

You can port-forward the controller deployment to test locally:

```bash
# Metrics
kubectl port-forward deployment/newresource-controller 8080:8080 -n newresource-system

# Health and readiness
kubectl port-forward deployment/newresource-controller 8081:8081 -n newresource-system
```

Test with curl:

```bash
curl -sf http://localhost:8081/healthz
curl -sf http://localhost:8081/readyz
curl -sf http://localhost:8080/metrics | head
```

## Exposed Metrics

The controller emits the following Prometheus metrics.

### controller_reconcile_total

- Type: CounterVec
- Labels:
  - controller: name of controller (e.g., NewResource)
  - result: one of started, success, error, not_found
- Description: Total number of reconciliation attempts by result type

Example queries:
```promql
# Total reconciliations per controller
sum by (controller) (increase(controller_reconcile_total[5m]))

# Error rate per controller
sum by (controller) (increase(controller_reconcile_total{result="error"}[5m]))
/
sum by (controller) (increase(controller_reconcile_total[5m]))
```

### controller_reconcile_duration_seconds

- Type: HistogramVec
- Labels:
  - controller: name of controller
- Description: Time spent reconciling resources

Example queries:
```promql
# 95th percentile reconcile duration over the last 5 minutes
histogram_quantile(0.95, sum by (le, controller) (rate(controller_reconcile_duration_seconds_bucket[5m])))

# Average duration by controller
sum by (controller) (rate(controller_reconcile_duration_seconds_sum[5m]))
/
sum by (controller) (rate(controller_reconcile_duration_seconds_count[5m]))
```

### controller_reconcile_errors_total

- Type: CounterVec
- Labels:
  - controller: name of controller
  - error_type: error classification (e.g., get_resource, status_update)
- Description: Total number of reconciliation errors

Example queries:
```promql
# Errors per error type
sum by (controller, error_type) (increase(controller_reconcile_errors_total[15m]))

# Error budget tracking
sum (increase(controller_reconcile_errors_total[1h]))
```

## Prometheus Scrape Configuration

If your cluster has Prometheus (e.g., Prometheus Operator, kube-prometheus-stack), configure a Service and ServiceMonitor/PodMonitor to scrape the metrics.

Example Service (a Service already exists in config/service.yaml exposing port 8080; ensure it matches your setup):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: newresource-controller-metrics
  namespace: newresource-system
  labels:
    app.kubernetes.io/name: newresource-controller
spec:
  selector:
    app.kubernetes.io/name: newresource-controller
    app.kubernetes.io/component: controller
  ports:
  - name: http-metrics
    port: 8080
    targetPort: 8080
```

Example PodMonitor for kube-prometheus-stack:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: newresource-controller
  namespace: newresource-system
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: newresource-controller
      app.kubernetes.io/component: controller
  podMetricsEndpoints:
  - port: http-metrics
    interval: 15s
```

If you are not using the Prometheus Operator, you can add a static scrape job to your Prometheus configuration:

```yaml
scrape_configs:
- job_name: newresource-controller
  kubernetes_sd_configs:
  - role: endpoints
  relabel_configs:
  - source_labels: [__meta_kubernetes_service_label_app_kubernetes_io_name]
    action: keep
    regex: newresource-controller
  - source_labels: [__meta_kubernetes_endpoint_port_name]
    action: keep
    regex: http-metrics
```

## Dashboards and Alerts

Suggested panels:
- Reconciliation rate by result
- Error rate by error type
- P95 and P99 reconciliation duration
- Controller liveness and readiness (via blackbox/probe or integration with K8s metrics)

Suggested alerts:
- High error rate sustained for 10m
- P95 duration above threshold for 15m
- Readiness probe failures > 0 for 5m

## Troubleshooting

- No metrics scraped
  - Verify Service exists and targets port 8080
  - Confirm labels on Pod match Service selector
  - Verify Prometheus has a matching scrape job or a PodMonitor
- Health endpoints failing
  - Check pod logs: `kubectl logs -f deployment/newresource-controller -n newresource-system`
  - Verify there are no port conflicts in args
- Duration histogram missing quantiles
  - Use histogram_quantile with rate over buckets, ensure scrape interval and data retention are sufficient

## Notes

- Metrics names and label sets are stable; avoid relabeling cardinality explosions
- Prefer dashboard aggregates over per-resource time series to limit cardinality
- If you add new controllers, ensure each uses a distinct controller label in metrics