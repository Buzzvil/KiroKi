# Loki v3 Deployment Status - 2025-12-02

## 현재 상태

### Gitploy 배포
- Deployment #4332: ✅ Success
- Commit: 2efba109d668a9ab64f52d63bcd647f3f3b83f18
- Loki Version: 3.4.6

### Pod 상태 (17:59 기준)

#### ✅ 정상 작동
- Gateway: 2/2 Running
- Distributor: 3/3 Running
- Querier: 3/3 Running
- Query Frontend: 2/2 Running
- Query Scheduler: 2/2 Running
- Chunks Cache: 1/1 Running
- Results Cache: 1/1 Running
- Canary: 12/12 Running

#### ❌ 실패 (IAM 권한 문제)
- Compactor: 0/1 CrashLoopBackOff
- Ingester Zone A: 0/1 CrashLoopBackOff
- Ingester Zone B: 0/1 CrashLoopBackOff
- Ingester Zone C: 0/1 CrashLoopBackOff
- Index Gateway: 0/1 Running (재시작 중)

## 문제 원인

### IAM 권한 오류
```
AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity
status code: 403
```

**원인**: Terraform PR #3715가 아직 머지되지 않아 IAM Role이 생성되지 않음

## 필요한 조치

### 1. Terraform PR 머지 및 Apply
- PR: https://github.com/Buzzvil/terraform-resource/pull/3715
- 생성 리소스:
  - S3 버킷: ops-buzzvil-loki-v3
  - IAM Role: eks-loki-v3-s3-role-ops
  - IAM Policy: S3 읽기/쓰기 권한
  - IRSA 설정

### 2. Terraform Apply 순서
```bash
# 1. PR 리뷰 및 승인
# 2. PR 머지
# 3. Atlantis plan 실행
atlantis plan

# 4. Plan 확인 후 apply
atlantis apply
```

### 3. Apply 후 확인
```bash
# IAM Role 확인
aws iam get-role --role-name eks-loki-v3-s3-role-ops

# S3 버킷 확인
aws s3 ls | grep loki-v3

# Loki Pod 재시작 (자동으로 재시작되지만 수동으로도 가능)
kubectl rollout restart statefulset -n loki-v3 loki-v3-compactor
kubectl rollout restart statefulset -n loki-v3 loki-v3-ingester-zone-a
kubectl rollout restart statefulset -n loki-v3 loki-v3-ingester-zone-b
kubectl rollout restart statefulset -n loki-v3 loki-v3-ingester-zone-c
kubectl rollout restart statefulset -n loki-v3 loki-v3-index-gateway
```

## 설정 변경 이력

### Deployment #4331 (실패)
- Loki 3.4.6 업그레이드
- use_thanos_objstore 활성화 시도
- 결과: use_thanos_objstore 필드가 Loki 3.4.6에서도 지원되지 않음

### Deployment #4332 (부분 성공)
- use_thanos_objstore 제거
- commonConfig.replication_factor: 2 설정
- 결과: 대부분의 컴포넌트 정상 작동, IAM 권한 문제로 일부 실패

## 최종 설정

```yaml
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
      admin: ops-buzzvil-loki-v3
  
  storage_config:
    tsdb_shipper:
      active_index_directory: /var/loki/index
      cache_location: /var/loki/index_cache
    aws:
      s3forcepathstyle: false
      # use_thanos_objstore 제거 (Loki 3.4.6에서 지원 안 됨)
```

## 다음 단계

1. ✅ Loki 설정 수정 완료
2. ✅ Gitploy 배포 완료
3. ⏳ Terraform PR #3715 머지 대기
4. ⏳ Atlantis apply 실행
5. ⏳ IAM Role 생성 확인
6. ⏳ Loki Pod 정상화 확인
