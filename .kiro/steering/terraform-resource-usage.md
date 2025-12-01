# Terraform Resource 저장소 사용법

## 저장소 정보
- Repository: https://github.com/Buzzvil/terraform-resource
- 목적: Buzzvil 클라우드 인프라를 Terraform으로 관리하는 IaC 중앙 저장소
- 기본 브랜치: master
- 배포 도구: Atlantis

## 디렉토리 구조
```
terraform-resource/
├── aws/                    # AWS 인프라 (플랫폼별 구분)
│   ├── devops/            # 공유 인프라 (EKS, VPC, IAM)
│   ├── demand-ad-engine/  # 광고 엔진
│   ├── supply-core/       # 공급 플랫폼
│   ├── datavil/           # 데이터 플랫폼
│   └── ...
├── confluent/             # Kafka 인프라
├── datadog/               # 모니터링
├── pagerduty/             # 인시던트 관리
├── teleport/              # 접근 제어
├── modules/               # 재사용 가능한 모듈
└── policies/              # Conftest 정책
```

## 서비스별 파일 구조
```
service-name/
├── main.tf          # provider, backend 설정
├── variables.tf     # 변수 선언
├── iam.tf          # IAM 리소스
├── ecr.tf          # ECR 레포지토리
├── s3.tf           # S3 버킷
├── dynamodb.tf     # DynamoDB 테이블
└── ...
```

## Backend 설정 패턴
```hcl
terraform {
  required_version = ">= 1.0"
  
  backend "remote" {
    organization = "buzzvil"
    workspaces {
      name = "service-name"
    }
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "ap-northeast-1"
  profile = "buzzvil"
  
  default_tags {
    tags = {
      "terraform.io"        = "true"
      "terraform.workspace" = "workspace-name"
      "terraform.env"       = "ops"
    }
  }
}
```

## 작업 프로세스
1. master 브랜치에서 새 브랜치 생성
2. 리소스 변경 작업
3. PR 생성
4. Atlantis가 자동으로 `terraform plan` 실행
5. 리뷰 후 승인
6. Atlantis 명령으로 `terraform apply` 실행

## Atlantis 명령어
```
atlantis plan      # 변경 계획 확인
atlantis apply     # 변경 적용
atlantis unlock    # 잠금 해제
```

## 주요 규칙
- 모든 AWS provider는 반드시 `default_tags` 포함
- 리소스 명명: `{environment}-{resource-name}` 패턴
- archived 디렉토리의 리소스는 삭제 금지
