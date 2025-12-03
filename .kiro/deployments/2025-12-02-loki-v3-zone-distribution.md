# Loki v3 Zone-Aware Pod Distribution

Date: 2025-12-02
Deployment: #4339
Status: ✅ **SUCCESS**

## 목적
Loki v3 컴포넌트들을 A존과 C존에 균등하게 분산하여 토폴로지 어노테이션이 효과적으로 작동하도록 설정

## 문제 상황
- 이전에는 대부분의 Pod가 A존에만 배치됨
- 토폴로지 어노테이션(`service.kubernetes.io/topology-mode: Auto`)이 있어도 C존에 Pod가 없어 cross-zone 트래픽 발생
- 각 존에 최소 3개씩 Pod가 있어야 zone-aware routing이 효과적

## 변경 사항

### 1. topologySpreadConstraints 추가
모든 multi-replica 컴포넌트에 zone 분산 설정 추가:
```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.kubernetes.io/component: <component-name>
```

### 2. Replicas 증가 (2개 존 × 3개 = 6개)
| Component | Before | After | HPA Min |
|-----------|--------|-------|---------|
| gateway | 2 | 6 | - |
| distributor | 3 | 6 | 3 → 6 |
| ingester | 3 | 6 | 3 → 6 |
| querier | 3 | 6 | 3 → 6 |
| queryFrontend | 2 | 6 | 2 → 6 |
| queryScheduler | 2 | 6 | - |
| indexGateway | 2 | 6 | - |

### 3. 설정 세부사항
- **maxSkew: 1**: 존 간 Pod 수 차이를 최대 1개로 제한
- **whenUnsatisfiable: DoNotSchedule**: 조건을 만족하지 못하면 스케줄링 거부
- **topologyKey: topology.kubernetes.io/zone**: 가용존 기준으로 분산

## 배포 정보

- **PR**: https://github.com/Buzzvil/buzz-k8s-resources/pull/1451
- **Commit**: dd974bd9
- **Gitploy**: Deployment #4339 (success)
- **Applied**: 2025-12-02 20:49

## 배포 후 검증

### Zone Distribution 확인
```bash
$ kubectl get pods -n loki-v3 -o wide | grep -E "distributor|ingester|querier|gateway|query-frontend|query-scheduler|index-gateway"

=== Zone Distribution Summary ===
   3 distributor ap-northeast-1a
   3 distributor ap-northeast-1c
   3 gateway ap-northeast-1a
   3 gateway ap-northeast-1c
   3 index-gateway ap-northeast-1a
   3 index-gateway ap-northeast-1c
   3 ingester ap-northeast-1a
   3 ingester ap-northeast-1c
   3 querier ap-northeast-1a
   3 querier ap-northeast-1c
   3 query-frontend ap-northeast-1a
   3 query-frontend ap-northeast-1c
   3 query-scheduler ap-northeast-1a
   3 query-scheduler ap-northeast-1c
```

✅ **모든 컴포넌트가 A존과 C존에 정확히 3개씩 균등 분산**

### 전체 Pod 수
```bash
$ kubectl get pods -n loki-v3 --no-headers | wc -l
54
```

### HPA 상태
```bash
$ kubectl get hpa -n loki-v3
NAME                  REFERENCE                        TARGETS                              MINPODS   MAXPODS   REPLICAS
loki-v3-distributor   Deployment/loki-v3-distributor   cpu: 1%/80%                          6         10        6
loki-v3-ingester      StatefulSet/loki-v3-ingester     memory: 1%/80%, cpu: <unknown>/80%   6         10        6
loki-v3-querier       Deployment/loki-v3-querier       memory: 3%/80%, cpu: 1%/80%          6         10        6
loki-v3-query-frontend Deployment/loki-v3-query-frontend cpu: 1%/80%                        6         10        6
```

✅ **모든 HPA의 minReplicas가 6으로 설정됨**

## 효과

### 1. Zone-Aware Routing 활성화
- 각 존에 충분한 Pod가 있어 토폴로지 어노테이션이 효과적으로 작동
- 클라이언트가 같은 존의 Pod로 우선 라우팅됨

### 2. Cross-Zone 트래픽 감소
- A존의 클라이언트 → A존의 Loki Pod
- C존의 클라이언트 → C존의 Loki Pod
- 네트워크 레이턴시 감소 및 데이터 전송 비용 절감

### 3. 고가용성 향상
- 한 존에 장애 발생 시 다른 존의 Pod로 자동 페일오버
- 각 존에 3개씩 있어 존 내부에서도 부하 분산 가능

### 4. 리소스 사용량
- 총 Pod 수: 30개 → 54개 (24개 증가)
- 주요 증가: distributor, ingester, querier, query-frontend 각 3개 → 6개
- 예상 리소스 증가: CPU ~80%, Memory ~80%

## 주의사항

### 스케일링 제약
- minReplicas가 6이므로 최소 6개 Pod 유지
- 트래픽이 적어도 6개 Pod가 항상 실행됨
- 비용 최적화가 필요한 경우 minReplicas 조정 고려

### Zone 장애 시나리오
- 한 존 전체 장애 시 나머지 존의 3개 Pod로 전체 트래픽 처리
- maxReplicas가 10이므로 자동 스케일업 가능
- 존 복구 시 자동으로 재분산

## 관련 작업
- Topology Annotations: Deployment #4338
- Helm Chart Upgrade: Deployment #4336
- Config Fix: Deployment #4332, #4333
- Task: loki-alloy-deployment

## 참고
- Kubernetes Topology Spread Constraints: https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/
- Pod Topology Spread Constraints: https://kubernetes.io/docs/concepts/workloads/pods/pod-topology-spread-constraints/
