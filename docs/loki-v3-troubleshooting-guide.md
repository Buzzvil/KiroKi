# Loki v3 Troubleshooting Guide

## 개요

이 문서는 Loki v3 배포 시 발생한 주요 문제들과 해결 방법을 정리합니다.

## 발생한 문제들

### 1. Memcached 포트 설정 오류

#### 문제 증상
```
level=warn msg="backgroundCache writeBackLoop Cache.Store fail" 
err="server=10.0.130.201:4090: dial tcp 10.0.130.201:4090: connect: connection refused"
```

Ingester가 chunks-cache와 results-cache에 연결할 수 없어 connection refused 에러 발생.

#### 원인 분석
- Memcached statefulset 템플릿에서 `-u {{ .port }}` 사용
- `-u` 옵션은 **user ID**를 지정하는 옵션 (포트가 아님)
- Memcached가 기본 포트 11211로 실행됨
- Ingester는 설정된 포트(4090, 4091)로 연결 시도 → 실패

#### 해결 방법

**파일:** `charts/loki-v3-custom/templates/memcached/_memcached-statefulset.tpl`

```diff
  args:
    - -m {{ .allocatedMemory }}
    - --extended=modern,track_sizes{{ if .persistence.enabled }},ext_path={{ .persistence.mountPath }}/file:{{ $persistenceSize }}G,ext_wbuf_size=16{{ end }}{{ with .extraExtendedOptions }},{{ . }}{{ end }}
    - -I {{ .maxItemMemory }}m
    - -c {{ .connectionLimit }}
    - -v
-   - -u {{ .port }}
+   - -p {{ .port }}
```

**변경 내용:**
- `-u {{ .port }}` → `-p {{ .port }}`
- `-p` 옵션이 포트를 지정하는 올바른 옵션

**영향 범위:**
- chunks-cache (port 4090)
- results-cache (port 4091)

#### 검증
```bash
# Memcached가 올바른 포트로 리스닝하는지 확인
kubectl --context buzzvil-eks-ops -n loki-v3 get statefulset loki-v3-chunks-cache -o yaml | grep -A 8 "args:"

# 출력 예시:
# - -p 4090  ✅ (올바름)
```

---

### 2. Alloy Distributor 포트 불일치

#### 문제 증상
```
level=error msg="final error sending batch, no retries left, dropping data" 
error="Post \"http://loki-v3-distributor.loki-v3.svc.cluster.local:4100/loki/api/v1/push\": context deadline exceeded"
```

Alloy가 Loki distributor로 로그를 전송하지 못하고 timeout 발생.

#### 원인 분석
- Loki v3에서 distributor HTTP 포트를 4100 → 4101로 변경
- Alloy 설정이 구 포트(4100)를 사용
- Distributor가 4101에서 리스닝하는데 Alloy는 4100으로 요청 → timeout

#### 해결 방법

**파일:** `argo-cd/buzzvil-eks-ops/apps/alloy-ops.yaml`

```diff
  loki.write "loki_v3" {
    endpoint {
-     url = "http://loki-v3-distributor.loki-v3.svc.cluster.local:4100/loki/api/v1/push"
+     url = "http://loki-v3-distributor.loki-v3.svc.cluster.local:4101/loki/api/v1/push"
    }
  }
```

**변경 내용:**
- Distributor 포트: 4100 → 4101

#### 배포 후 조치
Alloy DaemonSet 재시작 필요 (ConfigMap 변경 후 자동 재시작 안 됨):
```bash
kubectl --context buzzvil-eks-ops -n loki-v3 rollout restart daemonset alloy
```

#### 검증
```bash
# Alloy 로그에서 에러 확인
kubectl --context buzzvil-eks-ops -n loki-v3 logs -l app.kubernetes.io/name=alloy -c alloy --tail=50 | grep -i "error\|4100\|4101"

# 에러가 없으면 정상 ✅
```

---

### 3. Loki Canary Tail 요청 제한 초과

#### 문제 증상
```
error reading websocket, will retry in 10 seconds: 
websocket: close 1011 (internal server error): 
rpc error: code = Code(400) desc = max concurrent tail requests limit exceeded, count > limit (14 > 10)
```

Loki canary가 실시간 로그 tail 시 제한 초과 에러 발생.

#### 원인 분석
- Loki canary DaemonSet이 14개 pod 실행 중
- 각 canary pod가 tail 요청 생성
- Loki 기본 제한: `max_concurrent_tail_requests = 10`
- 14 > 10 → 제한 초과

#### 해결 방법

**파일:** `argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml`

```diff
  limits_config:
    ingestion_rate_mb: 50
    ingestion_burst_size_mb: 100
    max_query_parallelism: 256
    max_streams_per_user: 100000
+   max_concurrent_tail_requests: 20
    split_queries_by_interval: 30m
    max_query_length: 168h
```

**변경 내용:**
- `max_concurrent_tail_requests: 20` 추가
- 14개 canary pod + 여유분 고려하여 20으로 설정

#### 검증
```bash
# Canary pod 개수 확인
kubectl --context buzzvil-eks-ops -n loki-v3 get pods -l app.kubernetes.io/component=canary | wc -l

# Canary 로그에서 에러 확인
kubectl --context buzzvil-eks-ops -n loki-v3 logs -l app.kubernetes.io/component=canary --tail=50 | grep "limit exceeded"

# 에러가 없으면 정상 ✅
```

---

## 배포 절차

### 1. 변경사항 커밋
```bash
# buzz-k8s-resources 저장소에서 작업
cd repos/buzz-k8s-resources

# Feature 브랜치 생성
git checkout -b feat/loki-v3-custom-ports-for-cross-az-analysis

# 변경사항 커밋
git add charts/loki-v3-custom/templates/memcached/_memcached-statefulset.tpl
git commit -m "fix: memcached port configuration - use -p instead of -u"

git add argo-cd/buzzvil-eks-ops/apps/alloy-ops.yaml
git commit -m "fix: update Alloy distributor port from 4100 to 4101"

git add argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml
git commit -m "fix: increase max_concurrent_tail_requests to 20"

# 푸시
git push origin feat/loki-v3-custom-ports-for-cross-az-analysis
```

### 2. Gitploy로 배포

**⚠️ 중요:** buzz-k8s-resources는 `dynamic_payload`에 `app`과 `deployComment` 필수!

```bash
# 1. loki-v3 배포 (memcached 수정)
curl -X POST \
  -H "Authorization: Bearer $GITPLOY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "commit",
    "ref": "e7b9e49443c0e3e1463f60f8d4775655870bc430",
    "env": "buzzvil-eks-ops",
    "dynamic_payload": {
      "app": "loki-v3",
      "deployComment": "fix: memcached port configuration"
    }
  }' \
  https://gitploy.buzzvil.dev/api/v1/repos/Buzzvil/buzz-k8s-resources/deployments

# 2. alloy-ops 배포 (distributor 포트 수정)
curl -X POST \
  -H "Authorization: Bearer $GITPLOY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "commit",
    "ref": "cb0c84927392df69e90b5c3614743420dbad0e0f",
    "env": "buzzvil-eks-ops",
    "dynamic_payload": {
      "app": "alloy-ops",
      "deployComment": "fix: update Alloy distributor port to 4101"
    }
  }' \
  https://gitploy.buzzvil.dev/api/v1/repos/Buzzvil/buzz-k8s-resources/deployments

# 3. Alloy DaemonSet 재시작
kubectl --context buzzvil-eks-ops -n loki-v3 rollout restart daemonset alloy

# 4. loki-v3 배포 (tail 요청 제한 증가)
curl -X POST \
  -H "Authorization: Bearer $GITPLOY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "commit",
    "ref": "c1122068df82644473ffb2938099bf8904338bf6",
    "env": "buzzvil-eks-ops",
    "dynamic_payload": {
      "app": "loki-v3",
      "deployComment": "fix: increase max_concurrent_tail_requests to 20"
    }
  }' \
  https://gitploy.buzzvil.dev/api/v1/repos/Buzzvil/buzz-k8s-resources/deployments
```

### 3. 배포 검증

```bash
# 1. Ingester cache 연결 확인
kubectl --context buzzvil-eks-ops -n loki-v3 logs loki-v3-ingester-0 --since=5m | grep -i "connection refused"
# 출력 없으면 정상 ✅

# 2. Alloy 로그 전송 확인
kubectl --context buzzvil-eks-ops -n loki-v3 logs -l app.kubernetes.io/name=alloy -c alloy --tail=50 | grep -i "error"
# 출력 없으면 정상 ✅

# 3. Canary tail 요청 확인
kubectl --context buzzvil-eks-ops -n loki-v3 logs -l app.kubernetes.io/component=canary --tail=50 | grep "limit exceeded"
# 출력 없으면 정상 ✅

# 4. 전체 Pod 상태 확인
kubectl --context buzzvil-eks-ops -n loki-v3 get pods
# 모든 Pod가 Running/Ready 상태여야 함 ✅
```

---

## 교훈 및 Best Practices

### 1. Memcached 포트 설정
- `-u` 옵션: user ID (UID)
- `-p` 옵션: port number
- 혼동하지 않도록 주의!

### 2. 포트 변경 시 체크리스트
- [ ] 서비스 포트 변경
- [ ] 컨테이너 포트 변경
- [ ] ConfigMap/설정 파일 업데이트
- [ ] 클라이언트(Alloy 등) 설정 업데이트
- [ ] Readiness/Liveness probe 포트 업데이트

### 3. Gitploy 배포 시 주의사항
- buzz-k8s-resources는 `app` 필드 필수
- `app` 이름 = ArgoCD 애플리케이션 YAML 파일명 (확장자 제외)
- 예: `loki-v3.yaml` → `app: "loki-v3"`

### 4. ConfigMap 변경 후 재시작
- ArgoCD가 ConfigMap을 업데이트해도 Pod는 자동 재시작 안 됨
- DaemonSet/Deployment 수동 재시작 필요:
  ```bash
  kubectl rollout restart daemonset/deployment <name>
  ```

---

## 참고 자료

- [Memcached Command Line Options](https://github.com/memcached/memcached/wiki/ConfiguringServer)
- [Loki Configuration Reference](https://grafana.com/docs/loki/latest/configuration/)
- [Alloy Configuration](https://grafana.com/docs/alloy/latest/)
- [Gitploy 사용법](.kiro/steering/gitploy-usage.md)

---

### 4. trafficDistribution 설정 미적용 (2025-12-10)

#### 문제 증상
```bash
kubectl --context buzzvil-eks-ops -n loki-v3 get service loki-v3-distributor -o yaml | grep trafficDistribution
# 출력 없음 - trafficDistribution 설정이 적용되지 않음
```

#### 원인 분석
- ArgoCD 동기화가 완료되었지만 서비스에 `trafficDistribution: PreferClose` 설정이 반영되지 않음
- Kubernetes 1.30+ 버전에서 지원하는 기능이지만 클러스터 버전 확인 필요

#### 해결 방법

**1. 클러스터 버전 확인**
```bash
kubectl --context buzzvil-eks-ops version --short
```

**2. 서비스 템플릿 수정 확인**
모든 서비스 템플릿에 다음 패턴이 추가되었는지 확인:
```yaml
{{- with .Values.컴포넌트명.trafficDistribution | default .Values.loki.service.trafficDistribution }}
  trafficDistribution: {{ . }}
{{- end }}
```

**3. Values 설정 확인**
```yaml
loki:
  service:
    trafficDistribution: PreferClose
```

#### 검증
```bash
# ArgoCD 동기화 상태 확인
kubectl --context buzzvil-eks-ops -n argo-cd get application loki-v3-ops -o jsonpath='{.status.sync.status}'

# 서비스에 trafficDistribution 적용 확인
kubectl --context buzzvil-eks-ops -n loki-v3 get services -o yaml | grep -A 1 "trafficDistribution"
```

---

## VPC Flow Logs 활성화 및 Cross-AZ 트래픽 분석

### VPC Flow Logs 설정

#### 1. VPC Flow Logs 활성화
```bash
# buzzvil-eks-ops 클러스터의 VPC ID 확인
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=buzzvil-eks-ops-vpc" --query 'Vpcs[0].VpcId' --output text --profile sso-adfit-devops)

# S3 버킷 생성 (이미 있다면 생략)
aws s3 mb s3://buzzvil-vpc-flow-logs-ops --profile sso-adfit-devops

# VPC Flow Logs 활성화
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids $VPC_ID \
  --traffic-type ALL \
  --log-destination-type s3 \
  --log-destination "arn:aws:s3:::buzzvil-vpc-flow-logs-ops/vpc-flow-logs/" \
  --log-format '${version} ${account-id} ${interface-id} ${srcaddr} ${dstaddr} ${srcport} ${dstport} ${protocol} ${packets} ${bytes} ${windowstart} ${windowend} ${action} ${flowlogstatus}' \
  --profile sso-adfit-devops
```

#### 2. Flow Logs 데이터 확인
```bash
# 5-10분 후 S3에서 데이터 확인
aws s3 ls s3://buzzvil-vpc-flow-logs-ops/vpc-flow-logs/ --recursive --profile sso-adfit-devops
```

### Cross-AZ 트래픽 분석

#### 1. Loki v3 포트 필터링
```python
# Python 스크립트 예시
import pandas as pd
import boto3

# Loki v3 전용 포트 목록
loki_v3_ports = [4080, 4090, 4091] + list(range(4101, 4108)) + list(range(4201, 4208))

# VPC Flow Logs 데이터 로드
df = pd.read_csv('s3://buzzvil-vpc-flow-logs-ops/vpc-flow-logs/...')

# Loki v3 트래픽만 필터링
loki_v3_traffic = df[df['dstport'].isin(loki_v3_ports)]

# Cross-AZ 트래픽 분석
# Zone A: 10.0.128.0/22 (10.0.128.0 - 10.0.131.255)
# Zone C: 10.0.132.0/22 (10.0.132.0 - 10.0.135.255)

def get_zone(ip):
    ip_parts = ip.split('.')
    if ip_parts[0] == '10' and ip_parts[1] == '0':
        third_octet = int(ip_parts[2])
        if 128 <= third_octet <= 131:
            return 'Zone-A'
        elif 132 <= third_octet <= 135:
            return 'Zone-C'
    return 'Unknown'

loki_v3_traffic['src_zone'] = loki_v3_traffic['srcaddr'].apply(get_zone)
loki_v3_traffic['dst_zone'] = loki_v3_traffic['dstaddr'].apply(get_zone)

# Cross-AZ 트래픽 계산
cross_az_traffic = loki_v3_traffic[loki_v3_traffic['src_zone'] != loki_v3_traffic['dst_zone']]
total_bytes = loki_v3_traffic['bytes'].sum()
cross_az_bytes = cross_az_traffic['bytes'].sum()

print(f"Total Loki v3 traffic: {total_bytes / 1024**3:.2f} GB")
print(f"Cross-AZ traffic: {cross_az_bytes / 1024**3:.2f} GB")
print(f"Cross-AZ percentage: {(cross_az_bytes / total_bytes) * 100:.2f}%")
```

#### 2. trafficDistribution 효과 측정
```bash
# trafficDistribution 적용 전후 비교
# 1. 적용 전 데이터 수집 (2025-12-09 이전)
# 2. 적용 후 데이터 수집 (2025-12-10 이후)
# 3. Cross-AZ 트래픽 비율 비교

# kubectl debug를 이용한 실시간 모니터링
kubectl --context buzzvil-eks-ops -n loki-v3 debug -it loki-v3-distributor-0 \
  --image=nicolaka/netshoot --target=distributor

# 디버그 컨테이너 내부에서 실행
timeout 300 tcpdump -i any -n port 4101 and 'tcp[tcpflags] & (tcp-syn) != 0' 2>/dev/null | \
  awk '{print $3}' | cut -d'.' -f1-4 | tee /tmp/source_ips.log

# Zone별 트래픽 분석
echo "Zone A connections:"
grep -E '^10\.0\.(12[89]|13[01])\.' /tmp/source_ips.log | wc -l
echo "Zone C connections:"
grep -E '^10\.0\.(13[2-5])\.' /tmp/source_ips.log | wc -l
```

### 비용 분석

#### Cross-AZ 데이터 전송 비용 계산
```python
# AWS Cross-AZ 데이터 전송 비용: $0.01 per GB
cross_az_cost_per_gb = 0.01

# 일일 Cross-AZ 트래픽 (GB)
daily_cross_az_gb = cross_az_bytes / 1024**3

# 월간 예상 비용
monthly_cost = daily_cross_az_gb * 30 * cross_az_cost_per_gb

print(f"Daily Cross-AZ traffic: {daily_cross_az_gb:.2f} GB")
print(f"Monthly Cross-AZ cost: ${monthly_cost:.2f}")

# trafficDistribution 적용 후 절약 효과
# 예상 절약률: 70-80% (same-zone routing 효과)
estimated_savings = monthly_cost * 0.75
print(f"Estimated monthly savings: ${estimated_savings:.2f}")
```

---

## 작업 이력

### 2025-12-09: Custom Ports Configuration
- **작업자:** DevOps Team
- **브랜치:** feat/loki-v3-custom-ports-for-cross-az-analysis
- **배포 환경:** buzzvil-eks-ops
- **Gitploy Deployments:** #4369-#4374 (6회 순차 배포)
- **목적:** VPC Flow Logs에서 Loki v3 트래픽 구분을 위한 포트 변경

### 2025-12-10: Zone-Aware Traffic Routing
- **작업자:** DevOps Team
- **브랜치:** feat/loki-v3-custom-ports-for-cross-az-analysis (계속)
- **배포 환경:** buzzvil-eks-ops
- **Gitploy Deployment:** #4392
- **목적:** trafficDistribution: PreferClose 설정으로 Cross-AZ 트래픽 감소

### 주요 변경사항
1. **포트 구성 (2025-12-09)**
   - HTTP: 3100 → 4100-4107 (컴포넌트별)
   - gRPC: 9095 → 4201-4207 (컴포넌트별)
   - Gateway: 8080 → 4080
   - Cache: 11211 → 4090, 4091

2. **Zone-Aware 라우팅 (2025-12-10)**
   - 모든 서비스에 `trafficDistribution: PreferClose` 추가
   - 공식 Grafana Loki 차트 패턴 적용 (6.31.0+)
   - Same-zone 엔드포인트 우선 라우팅
