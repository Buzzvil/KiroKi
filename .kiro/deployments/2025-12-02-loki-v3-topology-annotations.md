# Loki v3 Topology Annotations Deployment

Date: 2025-12-02
Deployment: #4338
Status: ✅ **SUCCESS**

## 목적
Loki v3의 모든 Service 리소스에 토폴로지 어노테이션을 추가하여 cross-zone 트래픽 감소

## 변경 사항

### Service Annotations 수정
대부분의 컴포넌트에서 `service.annotations`를 `serviceAnnotations`로 변경:
- distributor
- ingester
- querier
- compactor
- indexGateway

### Service Annotations 추가
누락되었던 컴포넌트에 `serviceAnnotations` 추가:
- queryFrontend
- queryScheduler

### Gateway 유지
gateway는 다른 구조를 사용하므로 `gateway.service.annotations` 유지

## Helm 렌더링 검증

### 테스트 결과
```bash
$ helm template loki-v3 grafana/loki --version 6.30.0 -f values.yaml
✅ Helm rendering successful
```

### 적용된 Service 확인
```bash
$ helm template ... | yq 'select(.kind == "Service") | .metadata.name + ": " + .metadata.annotations."service.kubernetes.io/topology-mode"'

loki-v3-compactor: Auto
loki-v3-distributor-headless: Auto
loki-v3-distributor: Auto
loki-v3-gateway: Auto
loki-v3-index-gateway-headless: Auto
loki-v3-index-gateway: Auto
loki-v3-ingester-headless: Auto
loki-v3-ingester: Auto
loki-v3-querier: Auto
loki-v3-query-frontend-headless: Auto
loki-v3-query-frontend: Auto
loki-v3-query-scheduler: Auto
```

## 배포 정보

- **PR**: https://github.com/Buzzvil/buzz-k8s-resources/pull/1451
- **Commit**: 545d7dbc
- **Gitploy**: Deployment #4338 (success)
- **Applied**: 2025-12-02 20:34

## 배포 후 검증

### Service 토폴로지 어노테이션 확인
```bash
$ kubectl get svc -n loki-v3 -o json | jq -r '.items[] | select(.metadata.annotations."service.kubernetes.io/topology-mode" != null) | .metadata.name'

loki-v3-compactor
loki-v3-distributor
loki-v3-distributor-headless
loki-v3-gateway
loki-v3-index-gateway
loki-v3-index-gateway-headless
loki-v3-ingester
loki-v3-ingester-headless
loki-v3-querier
loki-v3-query-frontend
loki-v3-query-frontend-headless
loki-v3-query-scheduler
```

✅ **12개 Service에 토폴로지 어노테이션 적용 완료**

### 적용되지 않은 Service (의도적)
다음 Service들은 내부 통신용이므로 토폴로지 설정 불필요:
- loki-v3-chunks-cache (memcached)
- loki-v3-results-cache (memcached)
- loki-canary (모니터링)
- loki-v3-ruler (비활성화)
- loki-memberlist (내부 gossip)

## 효과

### Cross-Zone 트래픽 감소
- `service.kubernetes.io/topology-mode: Auto` 설정으로 Kubernetes가 자동으로 같은 zone의 Pod로 트래픽 라우팅
- 가능한 경우 zone 내부 통신 우선, 불가능한 경우에만 cross-zone 통신

### 예상 효과
- 네트워크 레이턴시 감소
- Cross-zone 데이터 전송 비용 절감
- 전반적인 성능 향상

## 관련 작업
- Helm Chart Upgrade: Deployment #4336
- Config Fix: Deployment #4332, #4333
- Task: loki-alloy-deployment

## 참고
- Kubernetes Topology Aware Routing: https://kubernetes.io/docs/concepts/services-networking/topology-aware-routing/
- Service Topology: https://kubernetes.io/docs/concepts/services-networking/service-topology/
