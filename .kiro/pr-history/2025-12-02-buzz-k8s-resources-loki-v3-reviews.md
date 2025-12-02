# PR #1447 Review Comments

- Repository: Buzzvil/buzz-k8s-resources
- PR URL: https://github.com/Buzzvil/buzz-k8s-resources/pull/1447
- Review Date: 2025-12-02

## Review Comments Summary

### 1. Project 설정
- **Reviewer**: Initial setup
- **Comment**: project를 devops로 변경
- **Status**: ✅ Fixed
- **Action**: project: data-platform → devops

### 2. ECR Pull-through Cache
- **Reviewer**: Copilot
- **Comment**: Docker Hub 대신 ECR mirror 사용
- **Status**: ✅ Fixed
- **Action**: registry: docker.io → 591756927972.dkr.ecr.ap-northeast-1.amazonaws.com/docker.io

### 3. syncPolicy 추가
- **Reviewer**: CodeRabbit
- **Comment**: CreateNamespace=true 추가 필요
- **Status**: ✅ Fixed
- **Action**: spec.syncPolicy.syncOptions에 CreateNamespace=true 추가

### 4. Loki 이미지 버전
- **Reviewer**: C0deWave, wattt3
- **Comment**: 3.2.2 패치 버전 사용
- **Status**: ✅ Fixed
- **Action**: tag: 3.2.0 → 3.2.2

### 5. Query Limits
- **Reviewer**: Copilot
- **Comment**: max_query_length/lookback이 retention보다 큼
- **Status**: ✅ Fixed
- **Action**: max_query_length: 721h → 168h, max_query_lookback: 720h → 168h

### 6. ServiceMonitor 위치
- **Reviewer**: chatgpt-codex-connector
- **Comment**: Loki chart v6에서는 monitoring.serviceMonitor 사용
- **Status**: ✅ Fixed
- **Action**: serviceMonitor → monitoring.serviceMonitor

### 7. 리소스 값 형식
- **Reviewer**: CodeRabbit
- **Comment**: CPU/Memory 값을 문자열로 표현
- **Status**: ✅ Fixed
- **Action**: 모든 리소스 값을 문자열로 변경 (예: cpu: "2", memory: "4Gi")

### 8. Chunk Encoding
- **Reviewer**: wattt3
- **Comment**: 비용 절감을 위해 zstd 사용
- **Status**: ✅ Fixed
- **Action**: chunk_encoding: snappy → zstd

### 9. Compactor 리소스
- **Reviewer**: wattt3
- **Comment**: ops 클러스터에는 과도하게 큼
- **Status**: ✅ Fixed
- **Action**: compactor resources: 1CPU/2Gi → 500m/1Gi

### 10. QueryScheduler 추가
- **Reviewer**: wattt3
- **Comment**: QueryScheduler 컴포넌트 고려
- **Status**: ✅ Fixed
- **Action**: queryScheduler 추가 (2 replicas, 200m/256Mi)

### 11. Gateway 필요성
- **Reviewer**: wattt3, dlddu
- **Comment**: 멀티테넌시를 위해 필수
- **Status**: ✅ Fixed
- **Action**: gateway 유지 (2 replicas)

### 12. Thanos Object Store
- **Reviewer**: wattt3
- **Comment**: use_thanos_objstore 옵션 추가
- **Status**: ✅ Fixed
- **Action**: storage_config.aws.use_thanos_objstore: true 추가

### 13. Schema From 날짜
- **Reviewer**: wattt3
- **Comment**: 너무 옛날 날짜
- **Status**: ✅ Fixed
- **Action**: from: "2024-01-01" → "2025-12-02"

### 14. Chunk Idle Period
- **Reviewer**: wattt3
- **Comment**: retention 기간과 일치시켜야 함
- **Status**: ✅ Fixed
- **Action**: chunk_idle_period: 30m → 168h

### 15. Replication Factor
- **Reviewer**: wattt3
- **Comment**: Buzzvil 표준은 2 (기본값 3)
- **Status**: ✅ Fixed
- **Action**: replication_factor: 2 추가

## Multi-tenancy 관련
- **Reviewer**: wattt3
- **Comment**: multi-tenancy 방식에서 agent가 고려해야 할 사항들이 있음
- **Status**: ⚠️ Note
- **Action**: Alloy agent 설정 시 고려 필요

## 미반영 사항
없음 - 모든 리뷰 피드백 반영 완료
