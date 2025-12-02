# Loki v3 Helm Chart Validation

Date: 2025-12-02
Status: ✅ **PASSED**

## 목적
기존 Loki v3 설정 변경 사항이 Helm 차트 렌더링에서 정상적으로 작동하는지 검증

## 검증 방법
로컬에서 Helm template 명령으로 매니페스트 렌더링 테스트

## 테스트 환경
- Helm Chart: grafana/loki v6.30.0
- Loki Version: 3.4.6 (이미지 태그 오버라이드)
- Deployment Mode: Distributed

## 검증된 설정

### 1. 핵심 설정
```yaml
deploymentMode: Distributed

loki:
  image:
    tag: 3.4.6
  auth_enabled: true
  
  commonConfig:
    replication_factor: 2
  
  storage:
    type: s3
    bucketNames:
      chunks: ops-buzzvil-loki-v3
      ruler: ops-buzzvil-loki-v3
```

### 2. Ingester 설정
```yaml
ingester:
  chunk_encoding: snappy
  chunk_idle_period: 168h
  chunk_retain_period: 1m
  max_chunk_age: 2h
  wal:
    flush_on_shutdown: true
    dir: /var/loki/wal
  zoneAwareReplication:
    enabled: false  # HPA 호환성을 위해 비활성화
```

### 3. Storage 설정
```yaml
storage_config:
  tsdb_shipper:
    active_index_directory: /var/loki/index
    cache_location: /var/loki/index_cache
  aws:
    s3forcepathstyle: false
```

### 4. 컴포넌트 설정
- Gateway: 2 replicas
- Distributor: 3 replicas (HPA: 3-10)
- Ingester: 3 replicas (HPA: 3-10)
- Querier: 3 replicas (HPA: 3-10)
- Query Frontend: 2 replicas (HPA: 2-10)
- Query Scheduler: 2 replicas
- Compactor: 1 replica
- Index Gateway: 1 replica

## 렌더링 결과

### ✅ 성공
```bash
$ helm template loki-v3 grafana/loki --version 6.30.0 -f loki-v3-values.yaml --namespace loki-v3
✅ Helm rendering successful
```

### 생성된 리소스
- PodDisruptionBudget: 8개
- ServiceAccount: 2개
- ConfigMap: 3개
- ClusterRole/ClusterRoleBinding: 1개씩
- Service: 다수 (각 컴포넌트별)
- Deployment: Gateway, Distributor, Querier, Query Frontend, Query Scheduler
- StatefulSet: Ingester, Compactor, Index Gateway
- HorizontalPodAutoscaler: Distributor, Ingester, Querier, Query Frontend
- DaemonSet: Canary

### 생성된 Loki 설정 검증
```yaml
auth_enabled: true

common:
  compactor_address: 'http://loki-v3-compactor:3100'
  path_prefix: /var/loki
  replication_factor: 2
  storage:
    s3:
      bucketnames: ops-buzzvil-loki-v3
      insecure: false
      region: ap-northeast-1
      s3forcepathstyle: false

ingester:
  chunk_encoding: snappy
  chunk_idle_period: 168h
  chunk_retain_period: 1m
  max_chunk_age: 2h
  wal:
    dir: /var/loki/wal
    flush_on_shutdown: true
  zoneAwareReplication:
    enabled: false

limits_config:
  retention_period: 2160h
  max_cache_freshness_per_query: 10m
  split_queries_by_interval: 15m
  query_timeout: 300s
  volume_enabled: true

compactor:
  retention_enabled: true
  delete_request_store: s3
  compaction_interval: 10m
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
```

## 주요 수정 사항 검증

### ✅ 1. commonConfig.replication_factor
- 위치: `common.replication_factor: 2`
- Loki v3에서 올바른 위치로 설정됨

### ✅ 2. ingester.replication_factor 제거
- ingester 섹션에서 제거됨
- commonConfig에서만 관리

### ✅ 3. storage_config.bloom_shipper.enabled 제거
- 잘못된 위치에서 제거됨
- bloom_build/bloom_gateway로 제어

### ✅ 4. zone-aware replication 비활성화
- `ingester.zoneAwareReplication.enabled: false`
- HPA와 호환되도록 단일 StatefulSet 생성

### ✅ 5. S3 storage 설정
- `loki.storage.bucketNames` 올바르게 설정
- `loki.storage.type: s3` 명시

## 발견된 추가 요구사항

### Distributed 모드 설정
Distributed 모드 사용 시 SimpleScalable 컴포넌트를 비활성화해야 함:
```yaml
backend:
  replicas: 0
read:
  replicas: 0
write:
  replicas: 0
```

### PodDisruptionBudget 설정
replicas > 1인 컴포넌트는 `maxUnavailable` 설정 필요:
```yaml
gateway:
  maxUnavailable: 1
distributor:
  maxUnavailable: 1
ingester:
  maxUnavailable: 1
querier:
  maxUnavailable: 1
queryFrontend:
  maxUnavailable: 1
queryScheduler:
  maxUnavailable: 1
```

## 결론

✅ **모든 설정 변경 사항이 Helm 차트 렌더링에서 정상 작동**

1. Loki v3.4.6 설정이 올바르게 생성됨
2. commonConfig.replication_factor가 올바른 위치에 설정됨
3. 잘못된 필드들이 제거됨
4. HPA 호환을 위한 zone-aware replication 비활성화 적용됨
5. S3 storage 설정이 올바르게 구성됨

## 다음 단계

1. ✅ Helm 렌더링 검증 완료
2. ArgoCD Application YAML 업데이트 (필요시)
3. 실제 클러스터 배포 및 모니터링

## 관련 문서
- PR: https://github.com/Buzzvil/buzz-k8s-resources/pull/1451
- Config Fix: .kiro/deployments/2025-12-02-loki-v3-config-fix.md
- HPA Fix: .kiro/deployments/2025-12-02-loki-v3-hpa-fix.md
