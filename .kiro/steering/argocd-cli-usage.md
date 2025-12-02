# ArgoCD CLI 사용법

## 개요
ArgoCD CLI는 ArgoCD 애플리케이션을 명령줄에서 관리하는 도구

## 인증

### 로그인
```bash
# 패스워드 로그인
argocd login <ARGOCD_SERVER>

# 토큰 로그인
argocd login <ARGOCD_SERVER> --auth-token <TOKEN>

# SSO 로그인
argocd login <ARGOCD_SERVER> --sso
```

### 컨텍스트 확인
```bash
argocd context
argocd context <CONTEXT_NAME>
```

## 애플리케이션 관리

### 애플리케이션 조회
```bash
# 전체 목록
argocd app list

# 특정 애플리케이션 상세 조회
argocd app get <APP_NAME>

# 상태 새로고침
argocd app get <APP_NAME> --refresh

# JSON 출력
argocd app get <APP_NAME> -o json
```

### 동기화 상태 확인
```bash
# Sync Status: Synced, OutOfSync, Unknown
# Health Status: Healthy, Progressing, Degraded, Suspended, Missing
argocd app get <APP_NAME>
```

## 리소스 관리

### 리소스 목록 조회
```bash
argocd app resources <APP_NAME>
```

### 리소스 상세 조회
```bash
argocd app manifests <APP_NAME>
```

### Diff 확인
```bash
argocd app diff <APP_NAME>
```

## 히스토리 조회

### 배포 히스토리 조회
```bash
argocd app history <APP_NAME>
```

## 로그 조회

### 애플리케이션 로그
```bash
argocd app logs <APP_NAME>

# 특정 컨테이너
argocd app logs <APP_NAME> --container <CONTAINER_NAME>

# Follow 모드
argocd app logs <APP_NAME> --follow
```

## 프로젝트 관리

### 프로젝트 목록
```bash
argocd proj list
```

### 프로젝트 상세 조회
```bash
argocd proj get <PROJECT_NAME>
```

## 클러스터 관리

### 클러스터 목록
```bash
argocd cluster list
```

## 유용한 옵션

### 출력 형식
```bash
-o json    # JSON 출력
-o yaml    # YAML 출력
-o wide    # 상세 출력
```

### 필터링
```bash
--selector <LABEL_SELECTOR>    # 라벨 선택자
--project <PROJECT_NAME>       # 프로젝트 필터
```

## Buzzvil 환경

### ArgoCD Server
- URL: https://argo-cd.buzzvil.dev
- 모든 클러스터 관리 (ops, dev, prod, honeyscreen)
- 애플리케이션: loki-v3, atlantis, gitploy 등

### 일반적인 워크플로우
```bash
# 1. 로그인
argocd login argo-cd.buzzvil.dev --sso

# 2. 애플리케이션 상태 확인
argocd app get loki-v3 --refresh

# 3. 로그 확인
argocd app logs loki-v3 --follow
```

## 참고
- 공식 문서: https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd/
- GitHub: https://github.com/argoproj/argo-cd
