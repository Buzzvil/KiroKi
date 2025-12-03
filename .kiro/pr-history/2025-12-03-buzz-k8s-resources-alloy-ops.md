# PR: Add Alloy ArgoCD Applications for Loki v3

**Repository**: buzz-k8s-resources  
**PR Number**: #1452  
**URL**: https://github.com/Buzzvil/buzz-k8s-resources/pull/1452  
**Author**: wattt3  
**Status**: Open  
**Created**: 2025-12-02  
**Related Task**: loki-alloy-deployment Task 4

## 목적

Loki v3로 로그를 수집하기 위한 Grafana Alloy 에이전트를 ops 클러스터에 먼저 배포 (테스트 목적)

## 변경 사항

### 파일 추가
- `argo-cd/buzzvil-eks-ops/apps/alloy-ops.yaml` (165 lines)

### 주요 설정

#### Helm 차트
- **Chart**: grafana/alloy
- **Version**: 1.4.0 (App Version: v1.11.3)
- **Repository**: https://grafana.github.io/helm-charts

#### 배포 설정
- **Namespace**: loki-v3
- **Controller Type**: DaemonSet
- **Priority Class**: system-node-critical
- **Tolerations**: Exists (모든 노드에서 실행)

#### Loki 연동
- **Endpoint**: http://loki-v3-distributor.loki-v3.svc.cluster.local:3100/loki/api/v1/push
- **Tenant ID**: ops

#### 리소스
```yaml
resources:
  limits:
    memory: 700Mi
  requests:
    cpu: 250m
    memory: 300Mi
```

## 주요 변경 이력

### Commit 1: Add Alloy ArgoCD Applications for all clusters
- 초기 버전: 3개 클러스터(ops, dev, prod) 모두 추가
- Chart version: 0.9.2

### Commit 2: Remove dev and prod Alloy applications
- dev, prod 파일 제거
- ops 클러스터만 먼저 테스트하기로 결정

### Commit 3: Add node filtering to Alloy discovery
- Node 필터링 추가: `field = "spec.nodeName=" + env("HOSTNAME")`
- 각 Alloy Pod가 자신의 노드 로그만 수집

### Commit 4: Fix instance label regex pattern for consistency
- Instance 레이블 정규식 수정
- 이전: `"^;*([^;]+)?$"`
- 현재: `"^;*([^;]+)(;.*)?$"`
- 다른 레이블(app, component)과 일관성 유지

### Commit 5: Upgrade Alloy chart version to 1.4.0 (v1.11.3)
- Chart version 업그레이드: 0.9.2 → 1.4.0
- App version: v1.4.3 → v1.11.3
- 2개월 전 안정 버전 선택

## 리뷰 코멘트

### CodeRabbit
- ✅ Instance 레이블 정규식 패턴 불일치 지적 → 수정 완료
- ✅ ArgoCD Application 구조 검증 통과
- ✅ Helm 차트 설정 검증 통과

### C0deWave
- ✅ Approved

## 로그 수집 설정

### Discovery 규칙
```alloy
discovery.kubernetes "pods" {
  role = "pod"
  selectors {
    role  = "pod"
    field = "spec.nodeName=" + env("HOSTNAME")
  }
}
```

### 레이블 추출
Promtail과 호환되는 레이블:
- `app`: 애플리케이션 이름
- `component`: 컴포넌트 이름
- `instance`: 인스턴스 식별자
- `node_name`: 노드 이름
- `namespace`: 네임스페이스
- `pod`: Pod 이름
- `container`: 컨테이너 이름

### 로그 처리 파이프라인
1. CRI 로그 파싱
2. RFC3339 타임스탬프 추출
3. filename 레이블 제거
4. Loki v3로 전송

## 모니터링 설정

### Prometheus
```yaml
serviceMonitor:
  enabled: true
  namespace: loki-v3
  labels:
    release: kube-prometheus-stack
```

### Datadog
```yaml
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "12345"
  ad.datadoghq.com/alloy.checks: |
    {
      "openmetrics": {
        "init_config": {},
        "instances": [
          {
            "openmetrics_endpoint": "http://%%host%%:12345/metrics",
            "namespace": "loki_v3",
            "metrics": [".*"]
          }
        ]
      }
    }
```

## 배포 전략

### Phase 1: ops 클러스터 (현재 PR)
- ops 클러스터에만 먼저 배포
- 로그 수집 및 Loki v3 연동 검증
- 리소스 사용량 모니터링

### Phase 2: dev 클러스터 (예정)
- ops 테스트 완료 후 별도 PR
- Tenant ID: dev

### Phase 3: prod 클러스터 (예정)
- dev 테스트 완료 후 별도 PR
- Tenant ID: prod

## 검증 항목

배포 후 확인:
- [ ] ArgoCD Application 동기화 상태
- [ ] Alloy Pod Running 상태
- [ ] 로그 수집 활동 확인
- [ ] Loki v3에서 ops 테넌트 로그 조회
- [ ] Prometheus 메트릭 수집
- [ ] Datadog 메트릭 수집
- [ ] 리소스 사용량 모니터링

## 관련 작업

- **KiroKi Task**: loki-alloy-deployment Task 4
- **Terraform PR**: https://github.com/Buzzvil/terraform-resource/pull/3715
- **Loki v3 배포**: 2025-12-02 완료

## 다음 단계

1. PR 머지
2. ArgoCD 동기화 확인
3. ops 클러스터 검증 (1-2일)
4. dev 클러스터 배포 준비
5. prod 클러스터 배포 준비
