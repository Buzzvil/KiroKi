# Loki v3 Troubleshooting Guide

## 개요

이 문서는 Loki v3 배포 시 발생한 주요 문제들과 해결 방법을 정리합니다.

## 최신 업데이트 (2025-12-10)

### trafficDistribution Configuration 추가

Zone-aware 트래픽 라우팅 지원으로 Cross-AZ 비용 절감:

```yaml
loki:
  service:
    trafficDistribution: PreferClose
```

이 설정은 공식 Grafana Loki 차트 패턴(6.31.0+)을 따라 같은 Zone의 엔드포인트로 우선 라우팅합니다.

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

### 2. Alloy Distributor 포트 불일치

#### 문제 증상
```
level=error msg="final error sending batch, no retries left, dropping data" 
error="Post \"http://loki-v3-distributor.loki-v3.svc.cluster.local:4100/loki/api/v1/push\": context deadline exceeded"
```

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

### 3. Loki Canary Tail 요청 제한 초과

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

### 4. trafficDistribution 설정 미적용 (2025-12-10)

#### 문제 증상
```bash
kubectl --context buzzvil-eks-ops -n loki-v3 get service loki-v3-distributor -o yaml | grep trafficDistribution
# 출력 없음 - trafficDistribution 설정이 적용되지 않음
```

#### 해결 방법

**1. 서비스 템플릿 수정**
모든 서비스 템플릿에 다음 패턴 추가:
```yaml
{{- with .Values.컴포넌트명.trafficDistribution | default .Values.loki.service.trafficDistribution }}
  trafficDistribution: {{ . }}
{{- end }}
```

**2. Values 설정**
```yaml
loki:
  service:
    trafficDistribution: PreferClose
```

## Zone-Aware Configuration

### 현재 상태
- **trafficDistribution**: PreferClose (전역 활성화)
- **Topology Spread Constraints**: 모든 컴포넌트 설정됨
- **Service Annotations**: `service.kubernetes.io/topology-mode: Auto`

### 검증 명령어

#### trafficDistribution 설정 확인
```bash
# 모든 서비스의 trafficDistribution 확인
kubectl --context buzzvil-eks-ops -n loki-v3 get services -o yaml | grep -A 1 "trafficDistribution"

# 특정 서비스 확인
kubectl --context buzzvil-eks-ops -n loki-v3 get service loki-v3-distributor -o jsonpath='{.spec.trafficDistribution}'
```

#### Cross-AZ 트래픽 모니터링
```bash
# kubectl debug를 이용한 트래픽 패턴 모니터링
kubectl --context buzzvil-eks-ops -n loki-v3 debug -it loki-v3-distributor-0 \
  --image=nicolaka/netshoot --target=distributor

# 디버그 컨테이너 내부에서 Source IP 모니터링
timeout 60 tcpdump -i any -n port 4101 2>/dev/null | \
  awk '{print $3}' | cut -d'.' -f1-4 | sort | uniq -c | sort -rn
```

## 포트 구성

Loki v3는 기존 Loki와 구분을 위해 커스텀 4000번대 포트 사용:

| Component | HTTP Port | gRPC Port | Purpose |
|-----------|-----------|-----------|---------|
| Gateway | 4080 | - | HTTP gateway |
| Distributor | 4101 | 4201 | Log ingestion |
| Ingester | 4102 | 4202 | Log storage |
| Querier | 4103 | 4203 | Query processing |
| Query Frontend | 4104 | 4204 | Query coordination |
| Query Scheduler | 4105 | 4205 | Query scheduling |
| Compactor | 4106 | 4206 | Data compaction |
| Index Gateway | 4107 | 4207 | Index management |

## VPC Flow Logs 분석

### Loki v3 트래픽 필터링
```python
# Loki v3 전용 포트로 트래픽 필터링
loki_v3_ports = [4080, 4090, 4091] + list(range(4101, 4108)) + list(range(4201, 4208))
```

### Zone 매핑 (buzzvil-eks-ops)
```python
def get_zone_ops(ip):
    parts = ip.split('.')
    if parts[0] == '10' and parts[1] == '0':
        third_octet = int(parts[2])
        # Zone A: 10.0.128.0/22 (10.0.128.0 - 10.0.131.255)
        if 128 <= third_octet <= 131:
            return 'ap-northeast-1a'
        # Zone C: 10.0.132.0/22 (10.0.132.0 - 10.0.135.255)
        elif 132 <= third_octet <= 135:
            return 'ap-northeast-1c'
    return 'unknown'
```

## 배포 히스토리

### 2025-12-09: Custom Ports Configuration
- **PR**: buzz-k8s-resources #1461
- **Gitploy**: #4369-#4374 (6회 순차 배포)
- **목적**: VPC Flow Logs에서 Loki v3 트래픽 구분

### 2025-12-10: Zone-Aware Traffic Routing
- **Gitploy**: #4392
- **목적**: trafficDistribution: PreferClose로 Cross-AZ 트래픽 감소

## 참고 자료

- [VPC Flow Logs Setup](../../docs/vpc-flow-logs-setup.md)
- [Deployment History](.kiro/deployments/2025-12-09-loki-v3-custom-ports.md)
- [PR History](.kiro/pr-history/2025-12-09-buzz-k8s-resources-loki-v3-ports.md)