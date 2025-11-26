# Requirements Document

## Introduction

이 문서는 Kubernetes 클러스터(ops, dev, prod)에 Loki 로그 수집 시스템과 Alloy 에이전트를 배포하고 모니터링하는 시스템의 요구사항을 정의합니다. Loki는 S3를 백엔드 스토리지로 사용하며, Alloy는 각 클러스터에서 로그를 수집하여 Loki로 전송합니다. 멀티테넌시 설정을 통해 안전한 로그 격리를 보장하고, 비용 모니터링을 통해 운영 효율성을 확보합니다.

## Glossary

- **Loki**: Grafana Labs에서 개발한 로그 수집 및 쿼리 시스템
- **Alloy**: 로그 수집 에이전트 (Grafana Agent의 후속 버전)
- **terraform-resources**: Terraform 코드를 관리하는 리포지토리
- **buzz-k8s-resources**: Kubernetes 헬름 차트를 관리하는 리포지토리
- **eks-ops**: EKS 클러스터 운영 리포지토리
- **Gitploy**: GitOps 기반 배포 도구
- **멀티테넌시**: 여러 테넌트(사용자/팀)가 동일한 시스템을 격리된 환경에서 사용하는 구조
- **DT**: DataDog 또는 관측성 도구 관련 비용
- **S3 버킷**: AWS Simple Storage Service의 객체 스토리지
- **IAM Role**: AWS Identity and Access Management 역할

## Requirements

### Requirement 1

**User Story:** 인프라 엔지니어로서, Loki가 로그를 저장할 S3 버킷과 필요한 IAM 권한을 프로비저닝하고 싶습니다. 이를 통해 Loki가 안전하게 로그 데이터를 저장하고 조회할 수 있습니다.

#### Acceptance Criteria

1. WHEN Terraform 코드가 실행되면 THE terraform-resources 리포지토리 SHALL S3 버킷을 생성한다
2. WHEN S3 버킷이 생성되면 THE terraform-resources 리포지토리 SHALL Loki가 사용할 IAM Role을 생성하고 적절한 권한을 부여한다
3. WHEN IAM Role이 생성되면 THE terraform-resources 리포지토리 SHALL S3 버킷에 대한 읽기 및 쓰기 권한을 Role에 할당한다
4. WHEN 리소스 생성이 완료되면 THE terraform-resources 리포지토리 SHALL 버킷 이름과 Role ARN을 출력한다

### Requirement 2

**User Story:** 플랫폼 엔지니어로서, buzz-k8s-resources 리포지토리에 Loki 헬름 차트를 설정하고 싶습니다. 멀티테넌시 설정을 통해 여러 팀의 로그를 안전하게 격리할 수 있습니다.

#### Acceptance Criteria

1. WHEN 헬름 차트가 생성되면 THE buzz-k8s-resources 리포지토리 SHALL Loki 헬름 차트 설정 파일을 포함한다
2. WHEN 헬름 차트가 구성되면 THE buzz-k8s-resources 리포지토리 SHALL 멀티테넌시 설정을 활성화한다
3. WHEN 멀티테넌시가 설정되면 THE buzz-k8s-resources 리포지토리 SHALL 테넌트별 로그 격리 정책을 정의한다
4. WHEN S3 백엔드가 구성되면 THE buzz-k8s-resources 리포지토리 SHALL Requirement 1에서 생성된 S3 버킷과 IAM Role을 참조한다

### Requirement 3

**User Story:** 운영 엔지니어로서, Loki를 EKS 클러스터에 배포하고 상태를 확인하고 싶습니다. Gitploy를 활용하여 안전하고 추적 가능한 배포를 수행할 수 있습니다.

#### Acceptance Criteria

1. WHEN Gitploy 배포가 트리거되면 THE eks-ops 리포지토리 SHALL Loki를 대상 클러스터에 배포한다
2. WHEN 배포가 완료되면 THE eks-ops 리포지토리 SHALL kubectl 명령을 통해 Loki Pod 상태를 조회할 수 있어야 한다
3. WHEN Loki Pod가 실행 중이면 THE eks-ops 리포지토리 SHALL Loki 서비스 엔드포인트가 접근 가능해야 한다
4. WHEN 배포 검증이 필요하면 THE eks-ops 리포지토리 SHALL Loki의 health check 엔드포인트가 정상 응답을 반환해야 한다

### Requirement 4

**User Story:** 비용 관리자로서, Loki 운영과 관련된 DT 비용을 모니터링하고 싶습니다. 비용 추이를 추적하여 예산을 효율적으로 관리할 수 있습니다.

#### Acceptance Criteria

1. WHEN 비용 데이터가 수집되면 THE 시스템 SHALL Loki 관련 리소스의 비용을 집계한다
2. WHEN 비용이 임계값을 초과하면 THE 시스템 SHALL 알림을 발송한다
3. WHEN 비용 리포트가 요청되면 THE 시스템 SHALL 일별, 주별, 월별 비용 추이를 제공한다

### Requirement 5

**User Story:** 플랫폼 엔지니어로서, buzz-k8s-resources 리포지토리에 Alloy 헬름 차트를 설정하고 싶습니다. Alloy가 각 클러스터에서 로그를 수집하여 Loki로 전송할 수 있습니다.

#### Acceptance Criteria

1. WHEN 헬름 차트가 생성되면 THE buzz-k8s-resources 리포지토리 SHALL Alloy 헬름 차트 설정 파일을 포함한다
2. WHEN Alloy가 구성되면 THE buzz-k8s-resources 리포지토리 SHALL Loki 엔드포인트를 대상으로 설정한다
3. WHEN 로그 수집 규칙이 정의되면 THE buzz-k8s-resources 리포지토리 SHALL 수집할 로그 소스와 필터링 규칙을 명시한다
4. WHEN 클러스터별 설정이 필요하면 THE buzz-k8s-resources 리포지토리 SHALL ops, dev, prod 환경별 values 파일을 제공한다

### Requirement 6

**User Story:** 운영 엔지니어로서, Alloy를 EKS 클러스터에 배포하고 상태를 확인하고 싶습니다. Gitploy를 활용하여 일관된 배포 프로세스를 유지할 수 있습니다.

#### Acceptance Criteria

1. WHEN Gitploy 배포가 트리거되면 THE eks-ops 리포지토리 SHALL Alloy를 대상 클러스터에 배포한다
2. WHEN 배포가 완료되면 THE eks-ops 리포지토리 SHALL kubectl 명령을 통해 Alloy Pod 상태를 조회할 수 있어야 한다
3. WHEN Alloy Pod가 실행 중이면 THE eks-ops 리포지토리 SHALL Alloy가 로그를 수집하고 있음을 확인할 수 있어야 한다

### Requirement 7

**User Story:** 운영 엔지니어로서, Alloy가 로그를 정상적으로 수집하고 있는지 확인하고 싶습니다. kubectl과 Alloy CLI를 통해 데이터 수집 상태를 모니터링할 수 있습니다.

#### Acceptance Criteria

1. WHEN kubectl 명령이 실행되면 THE 시스템 SHALL Alloy Pod의 로그를 조회하여 수집 상태를 확인할 수 있어야 한다
2. WHEN Alloy 메트릭이 조회되면 THE 시스템 SHALL 수집된 로그 라인 수와 전송 성공률을 표시해야 한다
3. WHEN 수집 오류가 발생하면 THE 시스템 SHALL 오류 메시지와 원인을 로그에 기록해야 한다

### Requirement 8

**User Story:** 운영 엔지니어로서, Loki에서 수집된 로그를 조회하고 싶습니다. Loki CLI 또는 API를 통해 로그 데이터가 정상적으로 저장되었는지 검증할 수 있습니다.

#### Acceptance Criteria

1. WHEN Loki 쿼리가 실행되면 THE 시스템 SHALL LogQL을 사용하여 로그를 검색할 수 있어야 한다
2. WHEN 특정 시간 범위의 로그가 요청되면 THE 시스템 SHALL 해당 기간의 로그를 반환해야 한다
3. WHEN 테넌트별 로그가 조회되면 THE 시스템 SHALL 해당 테넌트의 로그만 반환해야 한다
4. WHEN 로그 조회가 실패하면 THE 시스템 SHALL 명확한 오류 메시지를 제공해야 한다

### Requirement 9

**User Story:** 운영 엔지니어로서, S3에 로그가 정상적으로 저장되는지 확인하고 싶습니다. AWS CLI를 통해 S3 버킷의 객체를 조회하여 데이터 저장을 검증할 수 있습니다.

#### Acceptance Criteria

1. WHEN AWS CLI 명령이 실행되면 THE 시스템 SHALL S3 버킷의 객체 목록을 조회할 수 있어야 한다
2. WHEN 로그 파일이 조회되면 THE 시스템 SHALL 파일 크기와 생성 시간을 표시해야 한다
3. WHEN 읽기 권한이 부여되면 THE 시스템 SHALL S3 객체의 내용을 다운로드하고 읽을 수 있어야 한다
4. WHEN 로그 저장이 지연되면 THE 시스템 SHALL 최신 로그의 타임스탬프를 확인하여 지연 여부를 판단할 수 있어야 한다

### Requirement 10

**User Story:** 운영 엔지니어로서, 로그 수집 누락 여부를 확인하고 싶습니다. 예상되는 로그 볼륨과 실제 수집된 로그를 비교하여 데이터 손실을 감지할 수 있습니다.

#### Acceptance Criteria

1. WHEN 로그 볼륨이 측정되면 THE 시스템 SHALL 시간당 예상 로그 라인 수를 계산해야 한다
2. WHEN 실제 수집량이 조회되면 THE 시스템 SHALL Loki에 저장된 로그 라인 수를 집계해야 한다
3. WHEN 수집률이 계산되면 THE 시스템 SHALL 예상 대비 실제 수집률을 백분율로 표시해야 한다
4. WHEN 수집률이 임계값 미만이면 THE 시스템 SHALL 알림을 발송하고 누락된 소스를 식별해야 한다

### Requirement 11

**User Story:** 비용 관리자로서, Alloy 운영과 관련된 DT 비용을 모니터링하고 싶습니다. 에이전트 리소스 사용량과 관련 비용을 추적할 수 있습니다.

#### Acceptance Criteria

1. WHEN 비용 데이터가 수집되면 THE 시스템 SHALL Alloy 관련 리소스의 비용을 집계한다
2. WHEN 비용이 임계값을 초과하면 THE 시스템 SHALL 알림을 발송한다
3. WHEN 비용 리포트가 요청되면 THE 시스템 SHALL 클러스터별 비용 분석을 제공한다

### Requirement 12

**User Story:** 플랫폼 엔지니어로서, ops 클러스터에서 검증된 Loki와 Alloy 설정을 dev 클러스터에 배포하고 싶습니다. 동일한 설정을 재사용하여 일관성을 유지할 수 있습니다.

#### Acceptance Criteria

1. WHEN dev 클러스터 배포가 시작되면 THE 시스템 SHALL ops 클러스터와 동일한 헬름 차트를 사용해야 한다
2. WHEN 환경별 차이가 있으면 THE 시스템 SHALL dev 환경 전용 values 파일을 적용해야 한다
3. WHEN 배포가 완료되면 THE 시스템 SHALL Requirement 6과 7의 검증 절차를 수행해야 한다

### Requirement 13

**User Story:** 플랫폼 엔지니어로서, dev 클러스터에서 검증된 설정을 prod 클러스터에 배포하고 싶습니다. 프로덕션 환경에 안정적인 로그 수집 시스템을 구축할 수 있습니다.

#### Acceptance Criteria

1. WHEN prod 클러스터 배포가 시작되면 THE 시스템 SHALL dev 클러스터에서 검증된 헬름 차트를 사용해야 한다
2. WHEN 프로덕션 설정이 적용되면 THE 시스템 SHALL prod 환경 전용 values 파일을 적용해야 한다
3. WHEN 배포가 완료되면 THE 시스템 SHALL Requirement 6과 7의 검증 절차를 수행해야 한다
4. WHEN 프로덕션 배포가 완료되면 THE 시스템 SHALL 모든 클러스터(ops, dev, prod)의 로그가 Loki에서 조회 가능해야 한다
