# PR: Fix invalid Loki v3.2.2 config fields

- Repository: Buzzvil/buzz-k8s-resources
- PR URL: https://github.com/Buzzvil/buzz-k8s-resources/pull/1451
- Base Branch: feat/loki-v3-helm-chart
- Created: 2025-12-02
- Status: open

## 변경 목적
Loki v3.2.2와 호환되지 않는 설정 필드 제거. 모든 Loki 컴포넌트가 CrashLoopBackOff 상태로 실패하는 문제 해결.

## 문제 상황
배포 후 모든 Loki 컴포넌트(distributor, ingester, querier, compactor 등)가 설정 파싱 오류로 실패:

```
failed parsing config: /etc/loki/config/config.yaml: yaml: unmarshal errors:
  line 53: field replication_factor not found in type ingester.Config
  line 119: field use_thanos_objstore not found in type aws.StorageConfig
  line 121: field enabled not found in type config.Config
```

## 제거된 필드

### 1. ingester.replication_factor: 2
- ingester 섹션에 replication_factor를 설정할 수 없음
- common.replication_factor에만 설정 가능 (Helm 차트 기본값: 3)
- Buzzvil 표준이 2라면 common 섹션에서 설정해야 함

### 2. storage_config.aws.use_thanos_objstore: true
- Loki v3.x에서 제거된 필드
- S3 백엔드는 이 필드 없이도 정상 동작

### 3. storage_config.bloom_shipper.enabled: true
- 잘못된 필드 위치
- Bloom shipper는 최상위 bloom_build.enabled와 bloom_gateway.enabled로 제어

## 영향
- 모든 Loki 컴포넌트가 정상적으로 시작될 것으로 예상
- Pod 상태가 CrashLoopBackOff → Running으로 전환
- Loki v3가 ops 클러스터에서 완전히 작동

## 관련 작업
- Base PR: https://github.com/Buzzvil/buzz-k8s-resources/pull/1447
- Task: loki-alloy-deployment Task 3

## Diff
```diff
diff --git a/argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml b/argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml
index d858f133..1dd73ee2 100644
--- a/argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml
+++ b/argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml
@@ -56,7 +56,6 @@ spec:
             chunk_idle_period: 168h
             chunk_retain_period: 1m
             max_chunk_age: 2h
-            replication_factor: 2
             wal:
               flush_on_shutdown: true
               dir: /var/loki/wal
@@ -86,14 +85,11 @@ spec:
               insecure: false
           
           storage_config:
-            bloom_shipper:
-              enabled: true
             tsdb_shipper:
               active_index_directory: /var/loki/index
               cache_location: /var/loki/index_cache
             aws:
               s3forcepathstyle: false
-              use_thanos_objstore: true
           
           compactor:
             retention_enabled: true
```
