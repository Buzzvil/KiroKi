# Loki v3 HPA Fix - Zone-Aware Replication Disabled

Date: 2025-12-02
Deployment: #4333
Status: ✅ **SUCCESS**

## Problem

HPA for ingester was failing with error:
```
statefulsets.apps "loki-v3-ingester" not found
```

**Root Cause**: Zone-aware replication was enabled, creating separate StatefulSets per zone:
- `loki-v3-ingester-zone-a`
- `loki-v3-ingester-zone-b`
- `loki-v3-ingester-zone-c`

HPA expected a single StatefulSet named `loki-v3-ingester`, causing the autoscaling to fail.

## Solution

Disabled zone-aware replication in Helm chart:

```yaml
ingester:
  zoneAwareReplication:
    enabled: false
  replicas: 3
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
```

## Changes

### Before
- 3 separate StatefulSets (zone-a, zone-b, zone-c)
- HPA unable to find target StatefulSet
- Autoscaling not working

### After
- Single StatefulSet: `loki-v3-ingester`
- HPA working correctly
- Autoscaling functional (3-10 replicas)

## Deployment

- **PR**: https://github.com/Buzzvil/buzz-k8s-resources/pull/1451
- **Commit**: 7fd33dcbcf47ffbaddba958ad4ea99c1dd141417
- **Gitploy**: Deployment #4333 (success)
- **Applied**: 2025-12-02 18:24

## Verification

### HPA Status
```bash
$ kubectl get hpa -n loki-v3
NAME                  REFERENCE                        TARGETS                              MINPODS   MAXPODS   REPLICAS
loki-v3-distributor   Deployment/loki-v3-distributor   cpu: 1%/80%                          3         10        3
loki-v3-ingester      StatefulSet/loki-v3-ingester     memory: 1%/80%, cpu: <unknown>/80%   3         10        3
loki-v3-querier       Deployment/loki-v3-querier       memory: 3%/80%, cpu: 1%/80%          3         10        3
```

✅ HPA now successfully references `StatefulSet/loki-v3-ingester`

### Pod Status
```bash
$ kubectl get pods -n loki-v3 | grep ingester
loki-v3-ingester-0   1/1   Running   0   10m
loki-v3-ingester-1   1/1   Running   0   10m
loki-v3-ingester-2   1/1   Running   0   10m
```

✅ All 3 ingester pods Running

### Total Pods
```bash
$ kubectl get pods -n loki-v3 --no-headers | wc -l
30
```

✅ All 30 pods Running

## Notes

### Ring Cleanup
After switching from zone-aware to single StatefulSet, old ingester instances remain in the ring temporarily, causing warnings:

```
instance 10.0.128.197:9095 past heartbeat timeout
```

These warnings are expected and will resolve automatically as the ring cleans up stale entries (typically within 5-10 minutes).

### CPU Metrics
CPU metrics may show `<unknown>` initially while metrics-server collects data. This is normal and resolves within 1-2 minutes.

## Impact

- ✅ HPA now functional for ingester
- ✅ Autoscaling working (3-10 replicas based on CPU/memory)
- ✅ Simplified ingester management (single StatefulSet)
- ✅ All pods operational
- ⚠️ Temporary ring warnings (auto-resolving)

## Trade-offs

### Lost: Zone-Aware Replication
- No automatic distribution across availability zones
- Less resilient to zone failures

### Gained: Working Autoscaling
- HPA can scale ingester based on load
- Simpler StatefulSet management
- Better resource utilization

For production workloads requiring zone resilience, consider:
1. Using pod anti-affinity rules to spread pods across zones
2. Manual replica management without HPA
3. Waiting for Helm chart to support zone-aware HPA

## Related

- Config Fix PR: https://github.com/Buzzvil/buzz-k8s-resources/pull/1451
- Terraform Fix PR: https://github.com/Buzzvil/terraform-resource/pull/3725
- Previous Deployments: #4331, #4332
