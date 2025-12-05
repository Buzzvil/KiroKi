# Alloy Tolerations 수정 및 배포

**날짜**: 2025-12-05  
**작업자**: AI Assistant (Kiro)  
**관련 Task**: loki-alloy-deployment Task 4 후속 작업  
**PR**: https://github.com/Buzzvil/buzz-k8s-resources/pull/1452

## 문제 상황

Alloy DaemonSet이 ops 클러스터의 일부 노드에만 배포되고, taint가 있는 노드에는 배포되지 않는 문제 발견

### 증상
- 총 10개 노드 중 일부에만 Alloy Pod 배포됨
- Taint가 있는 노드에서 Pod가 Pending 상태

### 원인 분석

**Helm values 구조 오류**:
```yaml
# ❌ 잘못된 구조 (루트 레벨)
tolerations:
  - operator: "Exists"
```

Grafana Alloy Helm 차트는 `controller.tolerations` 경로를 사용해야 함:
```yaml
# ✅ 올바른 구조
controller:
  tolerations:
    - operator: "Exists"
```

### 영향받은 노드

Taint가 있는 노드 목록:
1. `ip-10-11-12-106.ap-northeast-1.compute.internal`
   - `node.kubernetes.io/unschedulable:NoSchedule`
2. `ip-10-11-12-123.ap-northeast-1.compute.internal`
   - `node.kubernetes.io/unschedulable:NoSchedule`
3. `ip-10-11-12-159.ap-northeast-1.compute.internal`
   - `node.kubernetes.io/unschedulable:NoSchedule`
4. `ip-10-11-12-173.ap-northeast-1.compute.internal`
   - `node.kubernetes.io/unschedulable:NoSchedule`
5. `ip-10-11-12-203.ap-northeast-1.compute.internal`
   - `node.kubernetes.io/unschedulable:NoSchedule`
6. `ip-10-11-12-230.ap-northeast-1.compute.internal`
   - `node.kubernetes.io/unschedulable:NoSchedule`
7. `ip-10-11-12-41.ap-northeast-1.compute.internal`
   - `node.kubernetes.io/unschedulable:NoSchedule`
8. `ip-10-11-12-72.ap-northeast-1.compute.internal`
   - `node.kubernetes.io/unschedulable:NoSchedule`
9. `ip-10-11-12-79.ap-northeast-1.compute.internal`
   - `node.kubernetes.io/unschedulable:NoSchedule`
10. `ip-10-11-13-11.ap-northeast-1.compute.internal`
    - `node.kubernetes.io/unschedulable:NoSchedule`

## 해결 방법

### 1. Helm Values 구조 수정

**파일**: `repos/buzz-k8s-resources/argo-cd/buzzvil-eks-ops/apps/alloy-ops.yaml`

**변경 내용**:
```yaml
# Before
tolerations:
  - operator: "Exists"

# After
controller:
  tolerations:
    - operator: "Exists"
```

### 2. Git 작업

```bash
cd repos/buzz-k8s-resources
git checkout feat/add-alloy-applications
git pull origin feat/add-alloy-applications

# 파일 수정
git add argo-cd/buzzvil-eks-ops/apps/alloy-ops.yaml
git commit -m "fix: move tolerations to controller.tolerations in alloy-ops

- Fix Helm values structure for Grafana Alloy chart
- Move tolerations from root level to controller.tolerations
- This allows Alloy DaemonSet to run on nodes with taints
- Affected: 10 nodes with node.kubernetes.io/unschedulable taint"

git push origin feat/add-alloy-applications
```

### 3. Gitploy 배포

```bash
# 최신 커밋 SHA 확인
cd repos/buzz-k8s-resources
git log -1 --format="%H" feat/add-alloy-applications
# Output: 8531c7a49402ff7931704ea18d5ced0ba97f3168

# Gitploy API로 배포 생성
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

**배포 결과**:
- 배포 번호: #4354
- 상태: running
- 환경: buzzvil-eks-ops

## 검증 계획

배포 완료 후 확인 사항:

### 1. DaemonSet 상태 확인
```bash
kubectl --context buzzvil-eks-ops get daemonset -n loki-v3
kubectl --context buzzvil-eks-ops get pods -n loki-v3 -l app.kubernetes.io/name=alloy
```

**기대 결과**:
- DESIRED: 10 (전체 노드 수)
- CURRENT: 10
- READY: 10
- UP-TO-DATE: 10
- AVAILABLE: 10

### 2. 노드별 Pod 배포 확인
```bash
kubectl --context buzzvil-eks-ops get pods -n loki-v3 -l app.kubernetes.io/name=alloy -o wide
```

**확인 사항**:
- 모든 10개 노드에 Alloy Pod가 배포되었는지
- 이전에 Pending이었던 노드에도 Running 상태인지

### 3. 로그 수집 확인
```bash
# Alloy Pod 로그 확인
kubectl --context buzzvil-eks-ops logs -n loki-v3 -l app.kubernetes.io/name=alloy --tail=50

# Loki에서 로그 조회
logcli query --addr=https://loki-dev.buzzvil.dev \
  '{namespace="loki-v3"}' \
  --limit=100 --since=1h --forward
```

### 4. 리소스 사용량 모니터링
```bash
kubectl --context buzzvil-eks-ops top pods -n loki-v3 -l app.kubernetes.io/name=alloy
```

**확인 사항**:
- CPU 사용량이 250m 이하인지
- Memory 사용량이 700Mi 이하인지

## 학습 내용

### Helm Chart Values 구조의 중요성

1. **차트별 구조 확인 필수**
   - 각 Helm 차트는 고유한 values 구조를 가짐
   - 공식 문서나 `values.yaml` 파일 확인 필요

2. **Grafana Alloy 차트 특징**
   - Controller 관련 설정은 `controller.*` 경로 사용
   - `tolerations`, `nodeSelector`, `affinity` 등 모두 `controller` 하위

3. **테스트 방법**
   ```bash
   # Helm template으로 렌더링 결과 확인
   helm template alloy grafana/alloy -f values.yaml
   
   # 특정 리소스만 확인
   helm template alloy grafana/alloy -f values.yaml | grep -A 10 "tolerations"
   ```

### DaemonSet Tolerations 패턴

**모든 노드에 배포하려면**:
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

### Gitploy 사용 패턴

**buzz-k8s-resources 배포 시**:
- 환경 이름: `buzzvil-eks-ops` (ops 아님!)
- 필수 파라미터: `app`, `deployComment`
- `app` 값은 ArgoCD Application 파일명 (`.yaml` 제외)

## 관련 문서

- **Spec**: `.kiro/specs/loki-alloy-deployment/`
- **PR**: https://github.com/Buzzvil/buzz-k8s-resources/pull/1452
- **이전 배포 기록**: `.kiro/deployments/2025-12-03-alloy-ops-deployment.md`
- **Grafana Alloy Helm Chart**: https://github.com/grafana/alloy/tree/main/operations/helm/charts/alloy

## 다음 단계

1. ✅ Tolerations 수정 완료
2. ✅ Gitploy 배포 실행
3. ⏳ 배포 완료 대기
4. ⏳ DaemonSet 상태 검증
5. ⏳ 로그 수집 확인
6. ⏳ 리소스 사용량 모니터링
7. ⏳ 1-2일 안정성 확인
8. ⏳ dev 클러스터 배포 준비
