# Atlantis 사용법

## 개요
Atlantis는 Terraform Pull Request 자동화 도구로, PR에 코멘트를 통해 `terraform plan`과 `apply`를 실행

## 기본 워크플로우
1. terraform-resource 저장소에서 브랜치 생성 및 작업
2. GitHub PR 생성
3. PR 코멘트에 `atlantis plan` 입력하여 plan 실행
4. Plan 결과 확인 후 리뷰 요청
5. 승인 후 `atlantis apply` 명령으로 배포

## 주요 명령어

### atlantis plan
```
atlantis plan
```
- Terraform plan 실행
- 변경 사항 미리보기

### atlantis apply
```
atlantis apply
```
- Terraform apply 실행
- 실제 인프라 변경 적용
- PR 승인 후에만 실행 가능

### atlantis unlock
```
atlantis unlock
```
- Workspace 잠금 해제
- Apply 실패나 중단 시 사용

### atlantis plan -p {project}
```
atlantis plan -p aws/devops
```
- 특정 프로젝트만 plan 실행
- 멀티 프로젝트 PR에서 유용

### atlantis apply -p {project}
```
atlantis apply -p aws/devops
```
- 특정 프로젝트만 apply 실행

## 사용 예시

### 단일 프로젝트 변경
```
1. PR 생성
2. PR 코멘트: "atlantis plan"
3. Plan 결과 확인
4. 리뷰어 승인
5. PR 코멘트: "atlantis apply"
6. Apply 완료 후 PR 머지
```

### 멀티 프로젝트 변경
```
1. PR 생성
2. PR 코멘트: "atlantis plan" → 모든 프로젝트 plan 실행
3. 각 프로젝트별 plan 결과 확인
4. 리뷰어 승인
5. PR 코멘트: "atlantis apply -p project1"
6. PR 코멘트: "atlantis apply -p project2"
7. 모든 apply 완료 후 PR 머지
```

## 주의사항
- Apply는 PR 승인 후에만 가능
- Apply 실행 중에는 workspace가 잠김
- 실패 시 unlock 필요
- Plan 결과를 반드시 확인 후 apply
- 삭제 작업은 특히 신중하게 검토

## 트러블슈팅

### Workspace 잠금 해제
```
atlantis unlock
```

### Plan 재실행
```
atlantis plan
```
또는 PR에 새 커밋 푸시

### 특정 프로젝트만 재실행
```
atlantis plan -p {project-name}
```

## 참고
- Atlantis는 PR 코멘트로만 동작
- 로컬에서 terraform 명령 실행 불가 (backend가 Terraform Cloud)
- Plan 결과는 PR 코멘트에 자동으로 표시됨
