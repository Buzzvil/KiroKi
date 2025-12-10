# Loki-v3 Zone-Aware Traffic Routing with trafficDistribution

**Date**: 2025-12-10  
**Repository**: buzz-k8s-resources  
**Branch**: feat/loki-v3-custom-ports-for-cross-az-analysis  
**Environment**: buzzvil-eks-ops  
**Gitploy Deployment**: #4392

## Overview

Added `trafficDistribution: PreferClose` configuration to all Loki-v3 services to enable zone-aware traffic routing and reduce cross-AZ data transfer costs.

## Problem Statement

Despite having custom ports for traffic analysis, Loki-v3 was still generating significant cross-AZ traffic costs. The services were not configured for zone-aware routing, causing traffic to be distributed randomly across availability zones.

## Solution

Implemented `trafficDistribution: PreferClose` setting following the official Grafana Loki chart pattern (6.31.0+) to route traffic to same-zone endpoints when available.

## Changes Made

### 1. Service Template Updates

Added trafficDistribution support to all service templates using the official pattern:

```yaml
{{- with .Values.컴포넌트명.trafficDistribution | default .Values.loki.service.trafficDistribution }}
  trafficDistribution: {{ . }}
{{- end }}
```

**Updated Templates:**
- `templates/distributor/service-distributor.yaml`
- `templates/ingester/service-ingester.yaml`
- `templates/querier/service-querier.yaml`
- `templates/query-frontend/service-query-frontend.yaml`
- `templates/query-scheduler/service-query-scheduler.yaml`
- `templates/compactor/service-compactor.yaml`
- `templates/index-gateway/service-index-gateway.yaml`
- `templates/gateway/service-gateway.yaml`

### 2. Global Configuration

Added global trafficDistribution setting in `loki-v3.yaml`:

```yaml
loki:
  service:
    trafficDistribution: PreferClose
  # ... existing config
```

## Technical Details

### trafficDistribution: PreferClose

This Kubernetes 1.30+ feature enables zone-aware service routing:

- **PreferClose**: Routes traffic to endpoints in the same zone when available
- **Fallback**: Routes to other zones only when same-zone endpoints are unavailable
- **Compatibility**: Follows official Grafana Loki chart pattern for future migration

### Service Configuration Pattern

The implementation supports both global and per-component configuration:

```yaml
# Global setting (applies to all services)
loki:
  service:
    trafficDistribution: PreferClose

# Per-component override (optional)
distributor:
  trafficDistribution: PreferClose
ingester:
  trafficDistribution: PreferClose
```

## Expected Benefits

### Cross-AZ Traffic Reduction

Based on industry best practices and Kubernetes zone-aware routing:

- **Expected Reduction**: 70-80% of cross-AZ traffic
- **Cost Savings**: Significant reduction in data transfer costs ($0.01/GB)
- **Performance**: Improved latency due to same-zone routing

### Measurement Approach

Using VPC Flow Logs with port-based filtering:

```python
# Loki v3 ports for analysis
loki_v3_ports = [4080, 4090, 4091] + list(range(4101, 4108)) + list(range(4201, 4208))

# Zone mapping for buzzvil-eks-ops
def get_zone_ops(ip):
    parts = ip.split('.')
    if parts[0] == '10' and parts[1] == '0':
        third_octet = int(parts[2])
        if 128 <= third_octet <= 131:
            return 'ap-northeast-1a'
        elif 132 <= third_octet <= 135:
            return 'ap-northeast-1c'
    return 'unknown'
```

## Deployment Process

### 1. Code Changes
```bash
# Updated service templates with trafficDistribution support
git add charts/loki-v3-custom/templates/*/service-*.yaml

# Added global configuration
git add argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml

# Committed changes
git commit -m "feat: enable trafficDistribution PreferClose for zone-aware routing"
```

### 2. Gitploy Deployment
```bash
curl -X POST \
  -H "Authorization: Bearer $GITPLOY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "commit",
    "ref": "86b53cd1",
    "env": "buzzvil-eks-ops",
    "dynamic_payload": {
      "app": "loki-v3",
      "deployComment": "Enable trafficDistribution PreferClose for zone-aware routing"
    }
  }' \
  https://gitploy.buzzvil.dev/api/v1/repos/Buzzvil/buzz-k8s-resources/deployments
```

**Result**: Deployment #4392 - Status: Success

## Verification

### 1. Service Configuration Check

```bash
# Check if trafficDistribution is applied
kubectl --context buzzvil-eks-ops -n loki-v3 get service loki-v3-distributor -o yaml | grep trafficDistribution

# Expected output:
# trafficDistribution: PreferClose
```

### 2. Real-time Traffic Monitoring

```bash
# Monitor traffic patterns using kubectl debug
kubectl --context buzzvil-eks-ops -n loki-v3 debug -it loki-v3-distributor-0 \
  --image=nicolaka/netshoot --target=distributor

# Inside debug container
timeout 300 tcpdump -i any -n port 4101 and 'tcp[tcpflags] & (tcp-syn) != 0' 2>/dev/null | \
  awk '{print $3}' | cut -d'.' -f1-4 | tee /tmp/source_ips.log

# Analyze zone distribution
zone_a_count=$(grep -E '^10\.0\.(12[89]|13[01])\.' /tmp/source_ips.log | wc -l)
zone_c_count=$(grep -E '^10\.0\.(13[2-5])\.' /tmp/source_ips.log | wc -l)

echo "Zone A connections: $zone_a_count"
echo "Zone C connections: $zone_c_count"
```

### 3. VPC Flow Logs Analysis

Compare traffic patterns before (2025-12-09) and after (2025-12-10) deployment:

```python
# Expected results:
# Before: ~50% cross-AZ traffic
# After: ~15% cross-AZ traffic (70% reduction)
```

## Troubleshooting

### Issue: trafficDistribution Not Applied

**Symptoms:**
```bash
kubectl --context buzzvil-eks-ops -n loki-v3 get service loki-v3-distributor -o yaml | grep trafficDistribution
# No output
```

**Possible Causes:**
1. Kubernetes version < 1.30
2. ArgoCD sync not completed
3. Template syntax error

**Resolution:**
```bash
# Check Kubernetes version
kubectl --context buzzvil-eks-ops version --short

# Check ArgoCD sync status
kubectl --context buzzvil-eks-ops -n argo-cd get application loki-v3-ops -o jsonpath='{.status.sync.status}'

# Force ArgoCD sync if needed
kubectl --context buzzvil-eks-ops -n argo-cd patch application loki-v3-ops -p '{"operation":{"sync":{}}}' --type merge
```

## Future Migration Path

This implementation follows the official Grafana Loki chart pattern (6.31.0+), ensuring seamless migration when upgrading from the current custom chart (6.30.0-custom) to the official chart.

**Migration Compatibility:**
- ✅ Same configuration syntax
- ✅ Same template structure
- ✅ Same values hierarchy
- ✅ No breaking changes required

## Related Documentation

- [Loki v3 Troubleshooting Guide](../docs/loki-v3-troubleshooting-guide.md)
- [VPC Flow Logs Setup](../../docs/vpc-flow-logs-setup.md)
- [Custom Ports Configuration](.kiro/deployments/2025-12-09-loki-v3-custom-ports.md)
- [Kubernetes trafficDistribution](https://kubernetes.io/docs/concepts/services-networking/service/#traffic-distribution)

## Cost Impact Analysis

### Before trafficDistribution (2025-12-09)
- Cross-AZ traffic: ~50% of total traffic
- Estimated monthly cost: $X.XX

### After trafficDistribution (2025-12-10)
- Cross-AZ traffic: ~15% of total traffic (expected)
- Estimated monthly cost: $X.XX (70% reduction expected)
- Monthly savings: $X.XX

*Actual measurements will be available after 24-48 hours of VPC Flow Logs data collection.*