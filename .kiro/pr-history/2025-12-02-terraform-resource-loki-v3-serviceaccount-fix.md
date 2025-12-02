# PR: Fix Loki v3 ServiceAccount pattern

- Repository: Buzzvil/terraform-resource
- PR URL: https://github.com/Buzzvil/terraform-resource/pull/3725
- Base Branch: master
- Created: 2025-12-02
- Status: merged
- Applied: 2025-12-02 (Atlantis)

## 변경 목적
Loki v3 Pod들이 IAM Role을 assume하지 못하는 문제 해결. Trust Policy의 ServiceAccount 이름 패턴이 실제 ServiceAccount 이름과 일치하지 않음.

## 문제 상황
모든 S3 접근이 필요한 Loki 컴포넌트(compactor, ingester, index-gateway)가 IAM 권한 오류로 실패:

```
AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity
status code: 403
```

**원인**: 
- IAM Role Trust Policy: `system:serviceaccount:loki-v3:loki-v3*`
- 실제 ServiceAccount: `loki` (namespace: `loki-v3`)
- Helm 차트가 `loki`라는 이름으로 ServiceAccount 생성

## 변경 사항

### IAM Trust Policy 패턴 수정
```hcl
# Before
values = ["system:serviceaccount:loki-v3:loki-v3*"]

# After  
values = ["system:serviceaccount:loki-v3:loki*"]
```

이제 `loki`, `loki-canary` 등 `loki`로 시작하는 모든 ServiceAccount가 IAM Role을 assume할 수 있습니다.

## 영향
- Compactor, Ingester, Index Gateway Pod들이 S3에 접근 가능
- 모든 Loki 컴포넌트가 정상 작동
- Loki v3가 완전히 작동 가능한 상태로 전환

## 적용 결과

### Atlantis Plan
- Command: `atlantis plan`
- Result: **Plan: 0 to add, 3 to change, 0 to destroy**
- Changes:
  - aws_iam_role.loki_v3_s3_role["ops"] - trust policy 업데이트
  - aws_iam_role.loki_v3_s3_role["dev"] - trust policy 업데이트
  - aws_iam_role.loki_v3_s3_role["prod"] - trust policy 업데이트

### Atlantis Apply
- Command: `atlantis apply`
- Result: ✅ **Apply complete!**
- Applied: 2025-12-02
- Resources modified: 3 IAM Roles

### 변경 내용
```
~ aws_iam_role.loki_v3_s3_role["ops"]
  ~ assume_role_policy: "loki-v3*" → "loki*"

~ aws_iam_role.loki_v3_s3_role["dev"]
  ~ assume_role_policy: "loki-v3*" → "loki*"

~ aws_iam_role.loki_v3_s3_role["prod"]
  ~ assume_role_policy: "loki-v3*" → "loki*"
```

### 검증
```bash
# IAM Role trust policy 확인
aws iam get-role --role-name eks-loki-v3-s3-role-ops \
  --query 'Role.AssumeRolePolicyDocument' \
  --profile sso-adfit-devops

# Loki Pod 상태 확인 (자동으로 재시작됨)
kubectl get pods -n loki-v3

# 로그 확인
kubectl logs -n loki-v3 loki-v3-compactor-0
```

## 관련 작업
- Base PR: #3715 (Loki v3 S3 buckets and IAM roles)
- buzz-k8s-resources PR: https://github.com/Buzzvil/buzz-k8s-resources/pull/1451
- Gitploy Deployment: #4332

## Diff
```diff
diff --git a/aws/devops/loki-v3/iam.tf b/aws/devops/loki-v3/iam.tf
index 3ef65159..c84ebda6 100644
--- a/aws/devops/loki-v3/iam.tf
+++ b/aws/devops/loki-v3/iam.tf
@@ -22,7 +22,7 @@ data "aws_iam_policy_document" "loki_v3_assume_role" {
     condition {
       test     = "StringLike"
       variable = "${each.value}:sub"
-      values   = ["system:serviceaccount:loki-v3:loki-v3*"]
+      values   = ["system:serviceaccount:loki-v3:loki*"]
     }
   }
 }
```
