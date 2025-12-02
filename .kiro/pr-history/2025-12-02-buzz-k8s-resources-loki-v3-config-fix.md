# PR: Fix invalid Loki v3.2.2 config fields and set replication_factor correctly

- Repository: Buzzvil/buzz-k8s-resources
- PR URL: https://github.com/Buzzvil/buzz-k8s-resources/pull/1451
- Base Branch: feat/loki-v3-helm-chart
- Created: 2025-12-02
- Status: open

## 변경 목적
Loki v3.2.2와 호환되지 않는 설정 필드로 인해 모든 Loki 컴포넌트가 CrashLoopBackOff 상태로 실패하는 문제 해결.

## 문제 상황
모든 Loki Pod가 다음 설정 파싱 오류로 실패:
```
failed parsing config: /etc/loki/config/config.yaml: yaml: unmarshal errors:
  line 53: field replication_factor not found in type ingester.Config
  line 119: field use_thanos_objstore not found in type aws.StorageConfig
  line 121: field enabled not found in type config.Config
```

## 변경 사항

### 1. commonConfig.replication_factor 추가
- Buzzvil 표준인 replication_factor: 2를 올바른 위치(commonConfig)에 설정
- Loki v3에서는 replication_factor가 commonConfig에만 설정되어야 함

### 2. ingester.replication_factor 제거
- ingester 섹션에서는 replication_factor를 설정할 수 없음
- commonConfig에서만 설정 가능

### 3. storage_config.aws.use_thanos_objstore 제거
- Loki v3.x에서 제거된 필드
- S3 백엔드는 이 필드 없이도 정상 동작

### 4. storage_config.bloom_shipper.enabled 제거
- 잘못된 필드 위치
- Bloom shipper는 최상위 bloom_build.enabled와 bloom_gateway.enabled로 제어됨

## 영향
- 모든 Loki 컴포넌트가 정상적으로 시작됨
- Pod 상태가 CrashLoopBackOff에서 Running으로 전환
- ops 클러스터에서 Loki v3가 완전히 작동
- Replication factor가 Buzzvil 표준(2)으로 올바르게 설정됨

## 관련 작업
- Base PR: #1447 (Loki v3 Helm chart 초기 설정)
- Task: loki-alloy-deployment Task 3

## Diff
```diff
diff --git a/argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml b/argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml
index d858f133..a1172c83 100644
--- a/argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml
+++ b/argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml
@@ -40,6 +40,9 @@ spec:
           
           auth_enabled: true
           
+          commonConfig:
+            replication_factor: 2
+          
           schemaConfig:
             configs:
               - from: "2025-12-02"
@@ -56,7 +59,6 @@ spec:
             chunk_idle_period: 168h
             chunk_retain_period: 1m
             max_chunk_age: 2h
-            replication_factor: 2
             wal:
               flush_on_shutdown: true
               dir: /var/loki/wal
@@ -86,14 +88,11 @@ spec:
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
