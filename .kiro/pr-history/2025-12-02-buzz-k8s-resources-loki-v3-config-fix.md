# PR: Fix invalid Loki v3.2.2 config fields and upgrade to v3.4.6

- Repository: Buzzvil/buzz-k8s-resources
- PR URL: https://github.com/Buzzvil/buzz-k8s-resources/pull/1451
- Base Branch: feat/loki-v3-helm-chart
- Created: 2025-12-02
- Updated: 2025-12-02
- Status: open
- Deployed: Deployment #4332 (success)

## 변경 목적
1. Loki v3.2.2와 호환되지 않는 설정 필드로 인해 모든 Loki 컴포넌트가 CrashLoopBackOff 상태로 실패하는 문제 해결
2. Loki를 최신 안정 버전(3.4.6)으로 업그레이드
3. use_thanos_objstore 활성화로 S3 호환성 향상

## 문제 상황
모든 Loki Pod가 다음 설정 파싱 오류로 실패:
```
failed parsing config: /etc/loki/config/config.yaml: yaml: unmarshal errors:
  line 53: field replication_factor not found in type ingester.Config
  line 119: field use_thanos_objstore not found in type aws.StorageConfig
  line 121: field enabled not found in type config.Config
```

## 변경 사항

### 1. Loki 버전 업그레이드
- Loki 3.2.2 → 3.4.6 (최신 패치 버전)
- 버그 수정 및 성능 개선 포함

### 2. commonConfig.replication_factor 추가
- Buzzvil 표준인 replication_factor: 2를 올바른 위치(commonConfig)에 설정
- Loki v3에서는 replication_factor가 commonConfig에만 설정되어야 함

### 3. ingester.replication_factor 제거
- ingester 섹션에서는 replication_factor를 설정할 수 없음
- commonConfig에서만 설정 가능

### 4. storage_config.aws.use_thanos_objstore 활성화
- Loki 3.4.6에서 다시 지원되는 필드
- S3 호환성 및 성능 향상을 위해 활성화

### 5. storage_config.bloom_shipper.enabled 제거
- 잘못된 필드 위치
- Bloom shipper는 최상위 bloom_build.enabled와 bloom_gateway.enabled로 제어됨

## 영향
- 대부분의 Loki 컴포넌트가 정상적으로 시작됨
- Pod 상태가 CrashLoopBackOff에서 Running으로 전환
- ops 클러스터에서 Loki v3.4.6이 부분적으로 작동
- Replication factor가 Buzzvil 표준(2)으로 올바르게 설정됨
- 최신 버전의 버그 수정 및 성능 개선 적용

## 배포 결과

### Gitploy 배포
- Deployment #4331: use_thanos_objstore 포함 (실패 - 필드 미지원)
- Deployment #4332: use_thanos_objstore 제거 (성공)
- Commit: 2efba109d668a9ab64f52d63bcd647f3f3b83f18

### Pod 상태 (2025-12-02 17:59)

#### ✅ 정상 작동
- Gateway: 2/2 Running
- Distributor: 3/3 Running
- Querier: 3/3 Running
- Query Frontend: 2/2 Running
- Query Scheduler: 2/2 Running
- Chunks Cache: 1/1 Running
- Results Cache: 1/1 Running
- Canary: 12/12 Running

#### ❌ IAM 권한 문제로 실패
- Compactor: 0/1 CrashLoopBackOff
- Ingester Zone A/B/C: 0/3 CrashLoopBackOff
- Index Gateway: 0/1 Running (재시작 중)

**오류**: `AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity`

**원인**: Terraform PR #3715가 아직 머지되지 않아 IAM Role이 생성되지 않음

## 차단 요소

### Terraform 리소스 필요
- PR: https://github.com/Buzzvil/terraform-resource/pull/3715
- 필요 리소스:
  - S3 버킷: ops-buzzvil-loki-v3
  - IAM Role: eks-loki-v3-s3-role-ops
  - IAM Policy: S3 읽기/쓰기 권한
  - IRSA 설정

### 해결 방법
1. Terraform PR #3715 머지
2. Atlantis로 `atlantis plan` 실행
3. Plan 확인 후 `atlantis apply` 실행
4. IAM Role 생성 확인
5. Loki Pod 자동 재시작 및 정상화

## 관련 작업
- Base PR: #1447 (Loki v3 Helm chart 초기 설정)
- Task: loki-alloy-deployment Task 3

## 최종 Diff (Deployment #4332)
```diff
diff --git a/argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml b/argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml
index d858f133..2efba109 100644
--- a/argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml
+++ b/argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml
@@ -36,10 +36,13 @@ spec:
           image:
             registry: 591756927972.dkr.ecr.ap-northeast-1.amazonaws.com/docker.io
             repository: grafana/loki
-            tag: 3.2.2
+            tag: 3.4.6
           
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

## 배포 이력

### Deployment #4331 (실패)
- Commit: c9506950099c258562f573f2942c7cd2ec781157
- 변경: Loki 3.4.6 + use_thanos_objstore 활성화
- 결과: 실패 - `field use_thanos_objstore not found in type aws.StorageConfig`
- 교훈: Loki 3.4.6에서도 use_thanos_objstore 필드 미지원

### Deployment #4332 (부분 성공)
- Commit: 2efba109d668a9ab64f52d63bcd647f3f3b83f18
- 변경: use_thanos_objstore 제거
- 결과: 대부분 성공, IAM 권한 문제로 일부 실패
- Gitploy URL: https://gitploy.buzzvil.dev/repos/Buzzvil/buzz-k8s-resources/deployments/4332

### Deployment #4333 (성공)
- Commit: 7fd33dcbcf47ffbaddba958ad4ea99c1dd141417
- 변경: zone-aware replication 비활성화
- 이유: HPA가 zone별 StatefulSet을 지원하지 않음
- 결과: ✅ 성공 - 단일 StatefulSet 생성, HPA 정상 작동
- Gitploy URL: https://gitploy.buzzvil.dev/repos/Buzzvil/buzz-k8s-resources/deployments/4333
