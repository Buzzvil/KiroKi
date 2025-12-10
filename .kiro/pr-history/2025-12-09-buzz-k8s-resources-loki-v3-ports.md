# buzz-k8s-resources PR: Loki-v3 Custom Ports Configuration

**Date**: 2025-12-09  
**PR Number**: #1461  
**Branch**: `feat/loki-v3-custom-ports-for-cross-az-analysis`  
**Status**: Draft  
**Repository**: Buzzvil/buzz-k8s-resources

## PR Title

feat: configure loki-v3 with custom ports for cross-AZ traffic analysis

## Description

Configure Loki-v3 with custom 4000-series ports to distinguish its traffic from existing Loki in VPC Flow Logs for accurate cross-AZ cost measurement.

## Port Changes

| Component | Original | New |
|-----------|----------|-----|
| HTTP | 3100 | 4100 |
| gRPC | 9095 | 4101 |
| Gateway | 8080 | 4080 |
| Chunks Cache | 11211 | 4090 |
| Results Cache | 11211 | 4091 |

## Files Modified

1. `argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml`
   - Added structuredConfig.server ports (4100/4101)
   - Added gateway.service.port (4080)
   - Added cache ports (4090/4091)
   - Added compactor_address with port 4100
   - Added readinessProbe for all components

2. `argo-cd/buzzvil-eks-ops/apps/alloy-ops.yaml`
   - Updated distributor URL to port 4100

## Commits

1. **c6396d04** - Initial port configuration
2. **eac09829** - Added memcached cache ports
3. **01dd3207** - Removed allocatedMemory
4. **3c880ae6** - Fixed compactor address
5. **749ab87a** - Updated readiness probes

## Gitploy Deployments

- #4369 - loki-v3 (initial ports)
- #4370 - alloy-ops (distributor URL)
- #4371 - loki-v3 (cache ports)
- #4372 - loki-v3 (memory fix)
- #4373 - loki-v3 (compactor address)
- #4374 - loki-v3 (readiness probes)

## Issues Fixed

- Connection refused errors to compactor
- Readiness probe failures on port 3100

## Related Links

- PR: https://github.com/Buzzvil/buzz-k8s-resources/pull/1461
- Deployment: `.kiro/deployments/2025-12-09-loki-v3-custom-ports.md`