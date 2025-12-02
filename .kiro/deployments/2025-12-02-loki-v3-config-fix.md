# Loki v3 Configuration Fix Required

Date: 2025-12-02
Issue: CrashLoopBackOff on all Loki components

## Problem

All Loki components are failing with config parsing errors:

```
failed parsing config: /etc/loki/config/config.yaml: yaml: unmarshal errors:
  line 53: field replication_factor not found in type ingester.Config
  line 119: field use_thanos_objstore not found in type aws.StorageConfig
  line 121: field enabled not found in type config.Config
```

## Root Cause

Three configuration fields are invalid for Loki v3.2.2:

1. **ingester.replication_factor** - Should be removed (already set in common.replication_factor)
2. **storage_config.aws.use_thanos_objstore** - Removed in Loki v3.x
3. **storage_config.bloom_shipper.enabled** - Invalid field location

## Required Changes

### buzz-k8s-resources PR #1447

File: `argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml`

#### Change 1: Remove ingester.replication_factor
```yaml
# REMOVE this from ingester section:
ingester:
  chunk_encoding: zstd
  chunk_idle_period: 168h
  chunk_retain_period: 1m
  chunk_target_size: 1536000
  max_chunk_age: 2h
  replication_factor: 2  # ❌ REMOVE THIS LINE
  wal:
    dir: /var/loki/wal
    flush_on_shutdown: true
    replay_memory_ceiling: 1GB
```

The replication_factor is already correctly set in `common.replication_factor: 3` (Helm chart default).
If we want replication_factor: 2, we should set it in the `common` section, not `ingester`.

#### Change 2: Remove use_thanos_objstore
```yaml
# REMOVE this from storage_config.aws:
storage_config:
  aws:
    s3forcepathstyle: false
    use_thanos_objstore: true  # ❌ REMOVE THIS LINE
```

This field was removed in Loki v3.x. The S3 backend works without it.

#### Change 3: Remove bloom_shipper.enabled
```yaml
# REMOVE this from storage_config:
storage_config:
  bloom_shipper:
    enabled: true  # ❌ REMOVE THIS LINE
    working_directory: /var/loki/data/bloomshipper
```

The bloom_shipper is controlled by `bloom_build.enabled` and `bloom_gateway.enabled` at the top level,
not by `storage_config.bloom_shipper.enabled`.

## Corrected Configuration

```yaml
loki:
  ingester:
    chunk_encoding: zstd
    chunk_idle_period: 168h
    chunk_retain_period: 1m
    chunk_target_size: 1536000
    max_chunk_age: 2h
    # replication_factor removed - use common.replication_factor instead
    wal:
      dir: /var/loki/wal
      flush_on_shutdown: true
      replay_memory_ceiling: 1GB
  
  storage_config:
    # aws.use_thanos_objstore removed - not needed in v3.x
    bloom_shipper:
      # enabled removed - controlled by bloom_build/bloom_gateway
      working_directory: /var/loki/data/bloomshipper
    tsdb_shipper:
      active_index_directory: /var/loki/index
      cache_location: /var/loki/index_cache
```

## Replication Factor Note

Currently `common.replication_factor: 3` (Helm default).
If Buzzvil standard is 2, update it in the `common` section:

```yaml
loki:
  commonConfig:
    replication_factor: 2
```

Or in the values:
```yaml
loki:
  common:
    replication_factor: 2
```

## Next Steps

1. Update buzz-k8s-resources PR #1447 with these changes
2. Commit and push
3. Gitploy will trigger new deployment
4. ArgoCD will sync the corrected configuration
5. Pods should start successfully
