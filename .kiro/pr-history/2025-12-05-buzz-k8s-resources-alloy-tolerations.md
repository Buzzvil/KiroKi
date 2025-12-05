# PR Update: Fix Alloy Tolerations Structure

**Repository**: buzz-k8s-resources  
**PR Number**: #1452  
**URL**: https://github.com/Buzzvil/buzz-k8s-resources/pull/1452  
**Branch**: feat/add-alloy-applications  
**Status**: Open  
**Updated**: 2025-12-05

## 업데이트 내용

### 문제 발견
Alloy DaemonSet이 ops 클러스터의 일부 노드에만 배포되는 문제 발견
- 총 10개 노드 중 taint가 있는 노드에 Pod가 배포되지 않음
- `node.kubernetes.io/unschedulable:NoSchedule` taint를 가진 노드에서 Pending 상태

### 원인
Helm values 구조 오류:
```yaml
# ❌ 잘못된 구조 (루트 레벨)
tolerations:
  - operator: "Exists"
```

Grafana Alloy Helm 차트는 `controller.tolerations` 경로를 사용:
```yaml
# ✅ 올바른 구조
controller:
  tolerations:
    - operator: "Exists"
```

### 수정 커밋

**Commit**: `8531c7a49402ff7931704ea18d5ced0ba97f3168`

**메시지**:
```
fix: move tolerations to controller.tolerations in alloy-ops

- Fix Helm values structure for Grafana Alloy chart
- Move tolerations from root level to controller.tolerations
- This allows Alloy DaemonSet to run on nodes with taints
- Affected: 10 nodes with node.kubernetes.io/unschedulable taint
```

**변경 파일**:
- `argo-cd/buzzvil-eks-ops/apps/alloy-ops.yaml`

**변경 내용**:
```diff
- tolerations:
-   - operator: "Exists"
+ controller:
+   tolerations:
+     - operator: "Exists"
```

## 영향받은 노드

Taint가 있어 Alloy Pod가 배포되지 않았던 노드 (10개):

1. `ip-10-11-12-106.ap-northeast-1.compute.internal`
2. `ip-10-11-12-123.ap-northeast-1.compute.internal`
3. `ip-10-11-12-159.ap-northeast-1.compute.internal`
4. `ip-10-11-12-173.ap-northeast-1.compute.internal`
5. `ip-10-11-12-203.ap-northeast-1.compute.internal`
6. `ip-10-11-12-230.ap-northeast-1.compute.internal`
7. `ip-10-11-12-41.ap-northeast-1.compute.internal`
8. `ip-10-11-12-72.ap-northeast-1.compute.internal`
9. `ip-10-11-12-79.ap-northeast-1.compute.internal`
10. `ip-10-11-13-11.ap-northeast-1.compute.internal`

모든 노드가 `node.kubernetes.io/unschedulable:NoSchedule` taint를 가지고 있음

## Gitploy 배포

### 배포 실행
```bash
curl -X POST \
  -H "Authorization: Bearer $GITPLOY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "commit",
    "ref": "8531c7a49402ff7931704ea18d5ced0ba97f3168",
    "env": "buzzvil-eks-ops",
    "dynamic_payload": {
      "app": "alloy-ops",
      "deployComment": "Add Alloy DaemonSet with tolerations for all node taints"
    }
  }' \
  https://gitploy.buzzvil.dev/api/v1/repos/Buzzvil/buzz-k8s-resources/deployments
```

### 배포 정보
- **배포 번호**: #4354
- **환경**: buzzvil-eks-ops
- **커밋**: 8531c7a49402ff7931704ea18d5ced0ba97f3168
- **상태**: running
- **배포 메시지**: "Add Alloy DaemonSet with tolerations for all node taints"

## 검증 계획

### 1. DaemonSet 상태
```bash
kubectl --context buzzvil-eks-ops get daemonset -n loki-v3
```

**기대 결과**:
- DESIRED: 10
- CURRENT: 10
- READY: 10
- UP-TO-DATE: 10
- AVAILABLE: 10

### 2. Pod 배포 상태
```bash
kubectl --context buzzvil-eks-ops get pods -n loki-v3 -l app.kubernetes.io/name=alloy -o wide
```

**확인 사항**:
- 모든 10개 노드에 Alloy Pod 배포 확인
- 모든 Pod가 Running 상태인지 확인

### 3. 로그 수집
```bash
# Alloy Pod 로그
kubectl --context buzzvil-eks-ops logs -n loki-v3 -l app.kubernetes.io/name=alloy --tail=50

# Loki에서 로그 조회
logcli query --addr=https://loki-dev.buzzvil.dev \
  '{namespace="loki-v3"}' \
  --limit=100 --since=1h --forward
```

### 4. 리소스 사용량
```bash
kubectl --context buzzvil-eks-ops top pods -n loki-v3 -l app.kubernetes.io/name=alloy
```

## 학습 내용

### Helm Chart Values 구조
- 각 Helm 차트는 고유한 values 구조를 가짐
- Grafana Alloy는 controller 관련 설정을 `controller.*` 경로에 배치
- 공식 문서나 `values.yaml` 파일 확인 필수

### Helm Template 테스트
```bash
# 렌더링 결과 확인
helm template alloy grafana/alloy -f values.yaml

# 특정 부분만 확인
helm template alloy grafana/alloy -f values.yaml | grep -A 10 "tolerations"
```

### DaemonSet Tolerations
**모든 노드에 배포**:
```yaml
controller:
  tolerations:
    - operator: "Exists"
```

**특정 taint만 허용**:
```yaml
controller:
  tolerations:
    - key: "node.kubernetes.io/unschedulable"
      operator: "Exists"
      effect: "NoSchedule"
```

## 관련 문서

- **배포 기록**: `.kiro/deployments/2025-12-05-alloy-tolerations-fix.md`
- **이전 배포**: `.kiro/deployments/2025-12-03-alloy-ops-deployment.md`
- **Spec**: `.kiro/specs/loki-alloy-deployment/`
- **Grafana Alloy Helm Chart**: https://github.com/grafana/alloy/tree/main/operations/helm/charts/alloy

## 다음 단계

1. ✅ Tolerations 수정 완료
2. ✅ Gitploy 배포 실행
3. ⏳ 배포 완료 대기
4. ⏳ DaemonSet 상태 검증
5. ⏳ 로그 수집 확인
6. ⏳ 리소스 사용량 모니터링
7. ⏳ 1-2일 안정성 확인 후 PR 머지
8. ⏳ dev 클러스터 배포 준비
