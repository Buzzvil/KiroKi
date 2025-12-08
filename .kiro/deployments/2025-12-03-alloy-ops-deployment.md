# Alloy Ops 클러스터 배포 기록

**날짜**: 2025-12-03  
**작업자**: AI Assistant (Kiro)  
**관련 Task**: loki-alloy-deployment Task 4  
**PR**: https://github.com/Buzzvil/buzz-k8s-resources/pull/1452

## 목적

Loki v3로 로그를 수집하기 위한 Grafana Alloy 에이전트를 ops 클러스터에 배포

## 배포 내용

### 1. ArgoCD Application 생성

**파일**: `argo-cd/buzzvil-eks-ops/apps/alloy-ops.yaml`

**주요 설정**:
- **Chart**: grafana/alloy v1.4.0 (App Version: v1.11.3)
- **Namespace**: loki-v3
- **Controller**: DaemonSet (모든 노드에서 로그 수집)
- **Loki Endpoint**: `http://loki-v3-distributor.loki-v3.svc.cluster.local:3100/loki/api/v1/push`
- **Tenant ID**: ops

### 2. 로그 수집 설정

#### Discovery 설정
```alloy
discovery.kubernetes "pods" {
  role = "pod"
  selectors {
    role  = "pod"
    field = "spec.nodeName=" + env("HOSTNAME")
  }
}
```

**특징**:
- 각 Alloy Pod가 자신이 실행 중인 노드의 Pod만 검색
- DaemonSet으로 배포되어 모든 노드에서 실행

#### 레이블 추출 규칙

Promtail과 호환되는 레이블 추출:
- `app`: 애플리케이션 이름 (app.kubernetes.io/name, app 레이블, controller name 순)
- `component`: 컴포넌트 이름 (app.kubernetes.io/component, component 레이블)
- `instance`: 인스턴스 식별자 (app.kubernetes.io/instance)
- `node_name`: 노드 이름
- `namespace`: 네임스페이스
- `pod`: Pod 이름
- `container`: 컨테이너 이름

#### 로그 처리 파이프라인

```alloy
loki.process "pods" {
  stage.cri {}
  
  stage.timestamp {
    source = "time"
    format = "RFC3339"
  }
  
  stage.labeldrop {
    values = ["filename"]
  }
  
  forward_to = [loki.write.loki_v3.receiver]
}
```

### 3. 리소스 설정

```yaml
resources:
  limits:
    memory: 700Mi
  requests:
    cpu: 250m
    memory: 300Mi
```

**근거**:
- Promtail 대비 2.5배 높은 리소스 할당
- Alloy는 더 많은 기능과 처리 능력 제공

### 4. 모니터링 설정

#### Prometheus ServiceMonitor
```yaml
serviceMonitor:
  enabled: true
  namespace: loki-v3
  labels:
    release: kube-prometheus-stack
```

#### Datadog OpenMetrics
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

### 5. 우선순위 및 Toleration

```yaml
priorityClassName: "system-node-critical"

tolerations:
  - operator: "Exists"
```

**근거**:
- 로그 수집은 시스템 핵심 기능
- 모든 노드에서 실행 가능하도록 모든 taint 허용

## 주요 변경사항

### 1. Helm 차트 버전 업그레이드
- **이전**: 0.9.2 (v1.4.3, 2024년 초)
- **현재**: 1.4.0 (v1.11.3, 2025-10-27)
- **근거**: 8개월 전 버전은 너무 오래됨, 2개월 전 안정 버전 선택

### 2. Instance 레이블 정규식 패턴 수정
- **이전**: `regex = "^;*([^;]+)?$"`
- **현재**: `regex = "^;*([^;]+)(;.*)?$"`
- **근거**: 다른 레이블(app, component)과 일관성 유지

### 3. Node 필터링 추가
- 각 Alloy Pod가 자신이 실행 중인 노드의 로그만 수집
- DaemonSet 특성에 맞는 최적화

## 배포 전략

### Phase 1: ops 클러스터 테스트 (현재)
- ops 클러스터에만 먼저 배포
- 로그 수집 및 Loki v3 연동 검증
- 리소스 사용량 모니터링

### Phase 2: dev 클러스터 배포 (예정)
- ops 테스트 완료 후 진행
- Tenant ID: dev
- 별도 PR로 배포

### Phase 3: prod 클러스터 배포 (예정)
- dev 테스트 완료 후 진행
- Tenant ID: prod
- 별도 PR로 배포

## 검증 항목

### 배포 후 확인 사항
- [ ] ArgoCD Application 동기화 상태 확인
- [ ] Alloy Pod Running 상태 확인
- [ ] Alloy Pod 로그에서 로그 수집 활동 확인
- [ ] Loki v3에서 ops 테넌트 로그 조회 확인
- [ ] Prometheus 메트릭 수집 확인
- [ ] Datadog 메트릭 수집 확인
- [ ] 리소스 사용량 모니터링

### 성능 검증
- [ ] CPU 사용량이 250m 이하인지 확인
- [ ] Memory 사용량이 700Mi 이하인지 확인
- [ ] 로그 수집 지연 시간 측정
- [ ] Loki v3 distributor 부하 확인

## 롤백 계획

문제 발생 시:
1. ArgoCD에서 Application 삭제
2. 기존 Promtail 계속 사용
3. 문제 분석 후 재배포

## 관련 문서

- **Spec**: `.kiro/specs/loki-alloy-deployment/`
- **PR**: https://github.com/Buzzvil/buzz-k8s-resources/pull/1452
- **Terraform PR**: https://github.com/Buzzvil/terraform-resource/pull/3715
- **Loki v3 배포 기록**: `.kiro/deployments/2025-12-02-loki-v3-*.md`

## 다음 단계

1. ops 클러스터 배포 및 검증
2. 로그 수집 상태 모니터링 (1-2일)
3. 문제 없으면 dev 클러스터 배포 준비
4. dev 클러스터 배포 및 검증
5. prod 클러스터 배포 준비
