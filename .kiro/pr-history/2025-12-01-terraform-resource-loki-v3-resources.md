# PR: Add Loki v3 S3 buckets and IAM roles

- Repository: Buzzvil/terraform-resource
- PR URL: https://github.com/Buzzvil/terraform-resource/pull/3715
- Created: 2025-12-01
- Status: open

## 변경 목적
Loki v3 업그레이드를 위한 새로운 AWS 리소스 프로비저닝. 기존 loki/loki2 리소스와 별도로 loki-v3 디렉토리를 생성하여 버전 업그레이드를 안전하게 진행.

## 생성 리소스
- S3 버킷: ops/dev/prod-buzzvil-loki-v3
- IAM Role: eks-loki-v3-s3-role-{ops,dev,prod}
- IAM Policy: S3 읽기/쓰기 권한 (PutObject, GetObject, ListBucket, DeleteObject)
- 라이프사이클: 7일 보관 정책
- IRSA 설정: EKS ServiceAccount와 IAM Role 연결

## Diff
```diff
diff --git a/aws/devops/loki-v3/iam.tf b/aws/devops/loki-v3/iam.tf
new file mode 100644
index 00000000..3ef65159
--- /dev/null
+++ b/aws/devops/loki-v3/iam.tf
@@ -0,0 +1,73 @@
+locals {
+  clusters = {
+    "ops"  = "oidc.eks.ap-northeast-1.amazonaws.com/id/8EC763E51D49A295A2DA87781DD2F9E8"
+    "dev"  = "oidc.eks.ap-northeast-1.amazonaws.com/id/C3D3B3CEE5DB85491FDD8A6FC1FA31AE"
+    "prod" = "oidc.eks.ap-northeast-1.amazonaws.com/id/69B8D71C25812E362D4FAEC6B02FB095"
+  }
+}
+
+data "aws_iam_policy_document" "loki_v3_assume_role" {
+  for_each = local.clusters
+
+  statement {
+    actions = ["sts:AssumeRoleWithWebIdentity"]
+    
+    principals {
+      type        = "Federated"
+      identifiers = ["arn:aws:iam::591756927972:oidc-provider/${each.value}"]
+    }
+    
+    effect = "Allow"
+    
+    condition {
+      test     = "StringLike"
+      variable = "${each.value}:sub"
+      values   = ["system:serviceaccount:loki-v3:loki-v3*"]
+    }
+  }
+}
+
+data "aws_iam_policy_document" "loki_v3_s3_policy" {
+  for_each = local.clusters
+
+  statement {
+    actions = [
+      "s3:PutObject",
+      "s3:GetObject",
+      "s3:ListBucket",
+      "s3:DeleteObject",
+    ]
+    
+    resources = [
+      aws_s3_bucket.loki_v3[each.key].arn,
+      "${aws_s3_bucket.loki_v3[each.key].arn}/*"
+    ]
+  }
+}
+
+resource "aws_iam_role" "loki_v3_s3_role" {
+  for_each = local.clusters
+
+  name               = "eks-loki-v3-s3-role-${each.key}"
+  assume_role_policy = data.aws_iam_policy_document.loki_v3_assume_role[each.key].json
+  
+  tags = {
+    "Service" = "loki-v3"
+    "Team"    = "devops"
+  }
+}
+
+resource "aws_iam_policy" "loki_v3_s3_policy" {
+  for_each = local.clusters
+
+  name        = "loki-v3-s3-policy-${each.key}"
+  description = "Loki v3 storage S3 policy for ${each.key}-buzzvil-loki-v3"
+  policy      = data.aws_iam_policy_document.loki_v3_s3_policy[each.key].json
+}
+
+resource "aws_iam_role_policy_attachment" "loki_v3_s3_policy" {
+  for_each = local.clusters
+
+  role       = aws_iam_role.loki_v3_s3_role[each.key].name
+  policy_arn = aws_iam_policy.loki_v3_s3_policy[each.key].arn
+}
diff --git a/aws/devops/loki-v3/main.tf b/aws/devops/loki-v3/main.tf
new file mode 100644
index 00000000..a4639e6e
--- /dev/null
+++ b/aws/devops/loki-v3/main.tf
@@ -0,0 +1,29 @@
+terraform {
+  
+  required_providers {
+    aws = {
+      source  = "hashicorp/aws"
+      version = "~> 5.0"
+    }
+  }
+
+  backend "remote" {
+    organization = "buzzvil"
+    workspaces {
+      name = "loki-v3"
+    }
+  }
+}
+
+provider "aws" {
+  region  = "ap-northeast-1"
+  profile = "adfit"
+
+  default_tags {
+    tags = {
+      "terraform.io"        = "true"
+      "terraform.workspace" = "loki-v3"
+      "terraform.env"       = "ops"
+    }
+  }
+}
diff --git a/aws/devops/loki-v3/outputs.tf b/aws/devops/loki-v3/outputs.tf
new file mode 100644
index 00000000..4489eb0a
--- /dev/null
+++ b/aws/devops/loki-v3/outputs.tf
@@ -0,0 +1,27 @@
+output "s3_bucket_names" {
+  description = "S3 bucket names for Loki v3 storage"
+  value = {
+    for k, v in aws_s3_bucket.loki_v3 : k => v.id
+  }
+}
+
+output "s3_bucket_arns" {
+  description = "S3 bucket ARNs for Loki v3 storage"
+  value = {
+    for k, v in aws_s3_bucket.loki_v3 : k => v.arn
+  }
+}
+
+output "iam_role_arns" {
+  description = "IAM Role ARNs for Loki v3 ServiceAccounts"
+  value = {
+    for k, v in aws_iam_role.loki_v3_s3_role : k => v.arn
+  }
+}
+
+output "iam_role_names" {
+  description = "IAM Role names for Loki v3 ServiceAccounts"
+  value = {
+    for k, v in aws_iam_role.loki_v3_s3_role : k => v.name
+  }
+}
diff --git a/aws/devops/loki-v3/s3.tf b/aws/devops/loki-v3/s3.tf
new file mode 100644
index 00000000..32271885
--- /dev/null
+++ b/aws/devops/loki-v3/s3.tf
@@ -0,0 +1,46 @@
+resource "aws_s3_bucket" "loki_v3" {
+  for_each = local.clusters
+
+  bucket = "${each.key}-buzzvil-loki-v3"
+
+  tags = {
+    "usage"       = "loki_v3_storage"
+    "Service"     = "loki-v3"
+    "Team"        = "devops"
+    "Environment" = each.key
+  }
+}
+
+resource "aws_s3_bucket_public_access_block" "loki_v3" {
+  for_each = local.clusters
+
+  bucket = aws_s3_bucket.loki_v3[each.key].id
+
+  block_public_acls       = true
+  block_public_policy     = true
+  ignore_public_acls      = true
+  restrict_public_buckets = true
+}
+
+resource "aws_s3_bucket_lifecycle_configuration" "loki_v3_lifecycle" {
+  for_each = aws_s3_bucket.loki_v3
+
+  bucket = each.value.id
+
+  rule {
+    id     = "7-days-retention"
+    status = "Enabled"
+
+    filter {
+      prefix = ""
+    }
+
+    expiration {
+      days = 7
+    }
+
+    noncurrent_version_expiration {
+      noncurrent_days = 7
+    }
+  }
+}
```
