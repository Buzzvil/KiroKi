# buzz-k8s-resources 저장소 사용법

## 저장소 정보
- Repository: https://github.com/Buzzvil/buzz-k8s-resources
- 목적: Buzzvil Kubernetes 클러스터의 애플리케이션 및 인프라를 관리하는 저장소
- 배포 도구: ArgoCD (GitOps)

## 디렉토리 구조
```
buzz-k8s-resources/
└── argo-cd/                    # ArgoCD 애플리케이션 정의
    ├── buzzvil-eks-ops/       # ops 클러스터
    │   ├── apps/              # ArgoCD Application 정의 (YAML)
    │   └── manifests/         # Kubernetes 매니페스트
    ├── buzzvil-eks/           # prod 클러스터
    │   ├── apps/
    │   └── manifests/
    ├── buzzvil-eks-dev/       # dev 클러스터
    │   ├── apps/
    │   └── manifests/
    └── honeyscreen-eks/       # honeyscreen 클러스터
        ├── apps/
        └── manifests/
```

## ArgoCD 애플리케이션 구조

### apps/ 디렉토리
ArgoCD Application 리소스를 정의하는 YAML 파일들이 위치
- 각 파일은 하나의 애플리케이션 배포를 정의
- Helm 차트 또는 Kubernetes 매니페스트를 참조

### manifests/ 디렉토리
애플리케이션별 Kubernetes 매니페스트 파일들이 위치
- 애플리케이션별 서브디렉토리로 구성
- ConfigMap, Secret, Deployment 등의 리소스 정의

## ArgoCD Application 정의 패턴

### Helm 차트 사용 예시
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: loki-ops
  namespace: argo-cd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: data-platform
  destination:
    namespace: loki
    server: https://kubernetes.default.svc
  source:
    chart: loki-distributed
    repoURL: https://grafana.github.io/helm-charts
    targetRevision: 0.53.2
    helm:
      releaseName: loki
      valuesObject:
        # Helm values 직접 정의
        key: value
```

### Manifest 디렉토리 사용 예시
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-manifests
  namespace: argo-cd
spec:
  project: default
  destination:
    namespace: target-namespace
    server: https://kubernetes.default.svc
  source:
    repoURL: https://github.com/Buzzvil/buzz-k8s-resources
    targetRevision: master
    path: argo-cd/buzzvil-eks-ops/manifests/app-name
```

## 작업 프로세스

### 1. 새 애플리케이션 배포
1. 저장소 클론
2. 적절한 클러스터 디렉토리 선택 (`argo-cd/{cluster-name}/`)
3. `apps/` 디렉토리에 Application YAML 작성
4. 필요시 `manifests/` 디렉토리에 리소스 정의
5. PR 생성 및 리뷰
6. 머지 후 ArgoCD가 자동으로 배포

### 2. 기존 애플리케이션 수정
1. 해당 클러스터의 `apps/` 또는 `manifests/` 파일 수정
2. PR 생성 및 리뷰
3. 머지 후 ArgoCD가 자동으로 동기화

## 클러스터별 배포

### ops 클러스터 (buzzvil-eks-ops)
- 운영 도구 및 인프라 컴포넌트
- ArgoCD, Atlantis, Gitploy, Loki, Prometheus 등

### prod 클러스터 (buzzvil-eks)
- 프로덕션 애플리케이션

### dev 클러스터 (buzzvil-eks-dev)
- 개발 환경 애플리케이션

## 주요 규칙
- 모든 변경은 PR을 통해 진행
- ArgoCD가 자동으로 배포하므로 직접 kubectl 사용 금지
- Application 정의는 `apps/` 디렉토리에 위치
- 매니페스트는 `manifests/` 디렉토리에 애플리케이션별로 구성
- Helm 차트는 공식 차트 사용 권장 (커스텀 차트는 `charts/` 디렉토리)

## ArgoCD 동기화
- 자동 동기화: master 브랜치 머지 후 자동으로 클러스터에 반영
- 수동 동기화: ArgoCD UI에서 Sync 버튼 클릭
- 동기화 정책은 Application YAML의 `syncPolicy`에서 설정

## 참고
- ArgoCD UI: 각 클러스터별로 접근 가능
- 배포 상태 확인: ArgoCD UI에서 실시간 확인
- 롤백: ArgoCD UI에서 이전 버전으로 롤백 가능
