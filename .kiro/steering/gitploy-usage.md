# Gitploy 사용법

## 개요
Gitploy는 GitHub Deployment API 기반 배포 자동화 도구로, 특정 ref(branch, tag, SHA)를 환경별로 배포 관리

## 접속 정보
- URL: https://gitploy.buzzvil.dev
- API Base: https://gitploy.buzzvil.dev/api/v1
- 인증: Bearer Token (환경변수 `GITPLOY_TOKEN` 사용)

## 기본 개념

### 배포 프로세스
1. 저장소 루트에 `deploy.yml` 파일로 환경 설정 정의
2. Gitploy API로 배포 생성 (ref + env 지정)
3. GitHub Deployment 이벤트 발생
4. GitHub Actions 워크플로우가 실제 배포 수행
5. Deployment Status로 배포 결과 업데이트

### deploy.yml 구조
```yaml
envs:
  - name: dev
    task: deploy:kubernetes
    auto_merge: false
    required_contexts:
      - "docker-image"
    deployable_ref: 'v.*\..*\..*'
    serialization: true
    dynamic_payload:
      enabled: true
      inputs:
        canaryEnabled:
          type: boolean
          default: false

  - name: prod
    task: deploy:kubernetes
    auto_merge: true
    required_contexts:
      - "docker-image"
    production_environment: true
    serialization: true
```

## API 사용법

### 인증
```bash
export GITPLOY_TOKEN="your-token"
curl -H "Authorization: Bearer $GITPLOY_TOKEN" https://gitploy.buzzvil.dev/api/v1/repos
```

### 저장소 조회
```bash
# 전체 저장소 목록
curl -H "Authorization: Bearer $GITPLOY_TOKEN" \
  https://gitploy.buzzvil.dev/api/v1/repos

# 활성화된 저장소만 필터링
curl -H "Authorization: Bearer $GITPLOY_TOKEN" \
  https://gitploy.buzzvil.dev/api/v1/repos | jq '.[] | select(.active == true)'

# 특정 저장소 검색
curl -H "Authorization: Bearer $GITPLOY_TOKEN" \
  "https://gitploy.buzzvil.dev/api/v1/repos?q=buzzstore"
```

### 설정 조회
```bash
# 저장소의 deploy.yml 설정 확인
curl -H "Authorization: Bearer $GITPLOY_TOKEN" \
  https://gitploy.buzzvil.dev/api/v1/repos/Buzzvil/buzzstore/config
```

### 배포 조회
```bash
# 배포 목록
curl -H "Authorization: Bearer $GITPLOY_TOKEN" \
  "https://gitploy.buzzvil.dev/api/v1/repos/Buzzvil/buzzstore/deployments?per_page=10"

# 환경별 필터링
curl -H "Authorization: Bearer $GITPLOY_TOKEN" \
  "https://gitploy.buzzvil.dev/api/v1/repos/Buzzvil/buzzstore/deployments?env=prod"

# 특정 배포 상세 조회
curl -H "Authorization: Bearer $GITPLOY_TOKEN" \
  https://gitploy.buzzvil.dev/api/v1/repos/Buzzvil/buzzstore/deployment/81
```

### 배포 생성
```bash
# 기본 배포
curl -X POST \
  -H "Authorization: Bearer $GITPLOY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "commit",
    "ref": "e2ded52f3f2c70a9e55a2d4ebd297b2b570f6f49",
    "env": "dev"
  }' \
  https://gitploy.buzzvil.dev/api/v1/repos/Buzzvil/buzzstore/deployments

# branch로 배포
curl -X POST \
  -H "Authorization: Bearer $GITPLOY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "branch",
    "ref": "main",
    "env": "dev"
  }' \
  https://gitploy.buzzvil.dev/api/v1/repos/Buzzvil/buzzstore/deployments

# tag로 배포
curl -X POST \
  -H "Authorization: Bearer $GITPLOY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "tag",
    "ref": "v1.2.3",
    "env": "prod"
  }' \
  https://gitploy.buzzvil.dev/api/v1/repos/Buzzvil/buzzstore/deployments

# dynamic_payload 포함
curl -X POST \
  -H "Authorization: Bearer $GITPLOY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "commit",
    "ref": "abc123",
    "env": "prod",
    "dynamic_payload": {
      "canaryEnabled": true
    }
  }' \
  https://gitploy.buzzvil.dev/api/v1/repos/Buzzvil/buzzstore/deployments
```

## 주요 필드 설명

### deploy.yml 환경 설정
- `name`: 환경 이름 (dev, prod 등)
- `task`: 배포 작업 타입 (deploy:kubernetes 등)
- `auto_merge`: 배포 성공 시 자동 머지 여부
- `required_contexts`: 배포 전 필수 체크 항목 (CI 상태 등)
- `production_environment`: 프로덕션 환경 여부
- `serialization`: 순차 배포 여부 (동시 배포 방지)
- `deployable_ref`: 배포 가능한 ref 패턴 (정규식)
- `dynamic_payload`: 배포 시 동적 파라미터 입력

### Deployment 응답
- `number`: 배포 번호
- `type`: ref 타입 (commit, branch, tag)
- `env`: 배포 환경
- `ref`: 배포한 ref
- `sha`: 실제 커밋 SHA
- `status`: 배포 상태 (waiting, queued, in_progress, success, failure)
- `is_rollback`: 롤백 배포 여부
- `production_environment`: 프로덕션 배포 여부

## 참고
- OpenAPI 스펙: `/openapi/v1/openapi.yaml`
- GitHub Deployment API: https://docs.github.com/en/rest/deployments
