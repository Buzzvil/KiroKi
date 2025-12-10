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

## Expected Benefits

### Cross-AZ Traffic Reduction

- **Expected Reduction**: 70-80% of cross-AZ traffic
- **Cost Savings**: Significant reduction in data transfer costs ($0.01/GB)
- **Performance**: Improved latency due to same-zone routing

## Deployment Process

### Gitploy Deployment #4392

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

### Real-time Traffic Monitoring

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

## Future Migration Path

This implementation follows the official Grafana Loki chart pattern (6.31.0+), ensuring seamless migration when upgrading from the current custom chart (6.30.0-custom) to the official chart.

## Related Documentation

- [Loki v3 Troubleshooting Guide](../docs/loki-v3-troubleshooting-guide.md)
- [Custom Ports Configuration](.kiro/deployments/2025-12-09-loki-v3-custom-ports.md)
- [Kubernetes trafficDistribution](https://kubernetes.io/docs/concepts/services-networking/service/#traffic-distribution)