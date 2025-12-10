# buzz-k8s-resources PR: Zone-Aware Traffic Routing

**Date**: 2025-12-10  
**Branch**: `feat/loki-v3-custom-ports-for-cross-az-analysis` (continued)  
**Status**: In Progress  
**Repository**: Buzzvil/buzz-k8s-resources

## PR Updates

### Latest Commit: 86b53cd1

feat: enable trafficDistribution PreferClose for zone-aware routing

## Description

Added `trafficDistribution: PreferClose` configuration to all Loki-v3 services following the official Grafana Loki chart pattern (6.31.0+) to reduce cross-AZ traffic costs.

## Changes Made

### Service Template Updates

Modified 8 service templates to support trafficDistribution:

1. `charts/loki-v3-custom/templates/distributor/service-distributor.yaml`
2. `charts/loki-v3-custom/templates/ingester/service-ingester.yaml`
3. `charts/loki-v3-custom/templates/querier/service-querier.yaml`
4. `charts/loki-v3-custom/templates/query-frontend/service-query-frontend.yaml`
5. `charts/loki-v3-custom/templates/query-scheduler/service-query-scheduler.yaml`
6. `charts/loki-v3-custom/templates/compactor/service-compactor.yaml`
7. `charts/loki-v3-custom/templates/index-gateway/service-index-gateway.yaml`
8. `charts/loki-v3-custom/templates/gateway/service-gateway.yaml`

### Global Configuration

Updated `argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml`:

```yaml
loki:
  service:
    trafficDistribution: PreferClose
```

## Deployment

### Gitploy Deployment #4392

**Status**: Success ✅

## Expected Impact

### Cross-AZ Traffic Reduction

- **Before**: ~50% cross-AZ traffic
- **After**: ~15% cross-AZ traffic (70% reduction expected)
- **Cost Savings**: Significant reduction in AWS data transfer costs

## Verification Methods

### 1. Service Configuration
```bash
kubectl --context buzzvil-eks-ops -n loki-v3 get services -o yaml | grep -A 1 "trafficDistribution"
```

### 2. Real-time Monitoring
```bash
kubectl --context buzzvil-eks-ops -n loki-v3 debug -it loki-v3-distributor-0 \
  --image=nicolaka/netshoot --target=distributor
```

### 3. VPC Flow Logs Analysis
- Compare 2025-12-09 (before) vs 2025-12-10 (after)
- Port-based filtering using Loki v3 ports (4080, 4090, 4091, 4101-4107, 4201-4207)

## Files Changed

```
charts/loki-v3-custom/templates/compactor/service-compactor.yaml
charts/loki-v3-custom/templates/distributor/service-distributor.yaml
charts/loki-v3-custom/templates/gateway/service-gateway.yaml
charts/loki-v3-custom/templates/index-gateway/service-index-gateway.yaml
charts/loki-v3-custom/templates/ingester/service-ingester.yaml
charts/loki-v3-custom/templates/querier/service-querier.yaml
charts/loki-v3-custom/templates/query-frontend/service-query-frontend.yaml
charts/loki-v3-custom/templates/query-scheduler/service-query-scheduler.yaml
argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml
```

**Total**: 9 files changed, 28 insertions(+)

## Related Links

- Deployment: `.kiro/deployments/2025-12-10-loki-v3-traffic-distribution.md`
- Previous Work: `.kiro/deployments/2025-12-09-loki-v3-custom-ports.md`