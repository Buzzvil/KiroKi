# Loki-v3 Custom Ports Configuration for Cross-AZ Traffic Analysis

**Date**: 2025-12-09  
**Repository**: buzz-k8s-resources  
**PR**: #1461  
**Environment**: buzzvil-eks-ops  
**Gitploy Deployments**: #4369, #4370, #4371, #4372, #4373, #4374

## Overview

Configured Loki-v3 with custom 4000-series ports to distinguish its traffic from existing Loki (port 3100) in VPC Flow Logs for accurate cross-AZ cost measurement.

## Problem Statement

When analyzing cross-AZ traffic costs using VPC Flow Logs, Loki-v3 traffic was indistinguishable from existing Loki traffic because both used the same ports (3100, 9095, 8080, 11211). This made it impossible to measure the cost impact of Loki-v3's topology-aware configuration separately.

## Solution

Changed all Loki-v3 component ports to 4000-series to enable port-based filtering in VPC Flow Logs analysis.

## Port Mapping

| Component | Original Port | New Port | Purpose |
|-----------|--------------|----------|---------|
| HTTP (all components) | 3100 | 4100 | Log ingestion, queries, API |
| gRPC (all components) | 9095 | 4101 | Internal communication |
| Gateway | 8080 | 4080 | HTTP gateway |
| Chunks Cache (memcached) | 11211 | 4090 | Chunk data caching |
| Results Cache (memcached) | 11211 | 4091 | Query result caching |

## Changes Made

### 1. loki-v3.yaml

#### Global Port Configuration
```yaml
loki:
  structuredConfig:
    server:
      http_listen_port: 4100
      grpc_listen_port: 4101
  
  commonConfig:
    replication_factor: 2
    compactor_address: 'http://loki-v3-compactor:4100'
```

#### Gateway Configuration
```yaml
gateway:
  service:
    port: 4080
```

#### Memcached Cache Configuration
```yaml
chunksCache:
  enabled: true
  replicas: 1
  port: 4090

resultsCache:
  enabled: true
  replicas: 1
  port: 4091
```

#### Readiness Probes (All Components)
```yaml
distributor:
  readinessProbe:
    httpGet:
      path: /ready
      port: 4100

ingester:
  readinessProbe:
    httpGet:
      path: /ready
      port: 4100

querier:
  readinessProbe:
    httpGet:
      path: /ready
      port: 4100

queryFrontend:
  readinessProbe:
    httpGet:
      path: /ready
      port: 4100

queryScheduler:
  readinessProbe:
    httpGet:
      path: /ready
      port: 4100

compactor:
  readinessProbe:
    httpGet:
      path: /ready
      port: 4100

indexGateway:
  readinessProbe:
    httpGet:
      path: /ready
      port: 4100
```

### 2. alloy-ops.yaml

Updated Alloy to send logs to the new Loki-v3 distributor port:

```yaml
loki.write "loki_v3" {
  endpoint {
    url = "http://loki-v3-distributor.loki-v3.svc.cluster.local:4100/loki/api/v1/push"
  }
}
```

## Deployment Sequence

1. **#4369** - Initial port configuration (HTTP 4100, gRPC 4101, Gateway 4080)
2. **#4370** - Updated Alloy distributor URL to port 4100
3. **#4371** - Added memcached cache ports (4090, 4091)
4. **#4372** - Removed allocatedMemory from cache config
5. **#4373** - Fixed compactor_address to use port 4100
6. **#4374** - Updated readiness probes for all components to port 4100

## Issues Resolved

### 1. Connection Refused Error
**Error**: `failed loading deletes for user: dial tcp 172.20.203.28:3100: connect: connection refused`

**Cause**: Components were trying to communicate with compactor using default port 3100, but compactor was listening on 4100.

**Fix**: Added `compactor_address: 'http://loki-v3-compactor:4100'` to commonConfig.

### 2. Readiness Probe Failures
**Error**: `Readiness probe failed: Get "http://10.0.130.248:3100/ready": dial tcp 10.0.130.248:3100: connect: connection refused`

**Cause**: Readiness probes were using default port 3100, but components were listening on 4100.

**Fix**: Added explicit readinessProbe configuration with port 4100 for all components.

## Verification

### Helm Template Validation
```bash
helm template loki-v3 grafana/loki --version 6.30.0 \
  -f loki-v3-values.yaml --namespace loki-v3 \
  | grep -E "(http_listen_port|grpc_listen_port|port: 4)"
```

**Output**:
```
grpc_listen_port: 4101
http_listen_port: 4100
port: 4080
```

### Pod Status Check
- ✅ 84/85 Pods running successfully
- ✅ Distributor logs show: `server listening on addresses http=[::]:4100 grpc=[::]:4101`
- ✅ Alloy successfully sending logs to port 4100

## VPC Flow Logs Analysis

With these port changes, you can now filter VPC Flow Logs by destination ports to isolate Loki-v3 traffic:

```python
# Filter for Loki-v3 traffic only
loki_v3_ports = [4080, 4090, 4091, 4100, 4101]
loki_v3_traffic = df[df['dstport'].isin(loki_v3_ports)]

# Filter for existing Loki traffic
existing_loki_ports = [3100, 8080, 9095, 11211]
existing_loki_traffic = df[df['dstport'].isin(existing_loki_ports)]
```

## Benefits

1. **Clear Traffic Separation**: Loki-v3 traffic is now completely distinguishable from existing Loki
2. **Accurate Cost Measurement**: Can measure cross-AZ costs for Loki-v3 independently
3. **No Service Disruption**: Port changes applied without affecting existing Loki deployment
4. **Topology Comparison**: Can compare cross-AZ costs between topology-aware (Loki-v3) and non-topology-aware (existing Loki) configurations

## Related Documentation

- PR: https://github.com/Buzzvil/buzz-k8s-resources/pull/1461
- Loki Architecture Comparison: `docs/loki-architecture-comparison.md`
- VPC Flow Logs Setup: `docs/vpc-flow-logs-setup.md`
- Cross-Zone Traffic Analysis: `docs/loki-cross-zone-traffic-analysis.md`
