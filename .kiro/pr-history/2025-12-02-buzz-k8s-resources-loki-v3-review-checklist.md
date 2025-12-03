# Loki v3 Helm Chart Review Checklist

PR: https://github.com/Buzzvil/buzz-k8s-resources/pull/1447

## Configuration Settings

- [x] Project 설정을 devops로 변경
- [x] ECR pull-through cache 사용 (591756927972.dkr.ecr.ap-northeast-1.amazonaws.com/docker.io)
- [x] syncPolicy.syncOptions에 CreateNamespace=true 추가
- [x] Loki 이미지 태그를 3.2.2로 업데이트

## Query & Retention Settings

- [x] max_query_length를 168h로 설정 (retention과 일치)
- [x] max_query_lookback를 168h로 설정 (retention과 일치)
- [x] retention_period 168h (7일) 유지
- [x] chunk_idle_period를 168h로 설정

## Monitoring & Observability

- [x] ServiceMonitor를 monitoring.serviceMonitor로 이동
- [x] ServiceMonitor labels에 release: kube-prometheus-stack 설정

## Resource Optimization

- [x] 모든 CPU/Memory 리소스 값을 문자열로 변경
- [x] chunk_encoding을 zstd로 변경 (비용 절감)
- [x] compactor 리소스를 500m/1Gi로 감소 (ops 클러스터 적정 크기)

## Component Configuration

- [x] queryScheduler 컴포넌트 추가 (2 replicas, 200m/256Mi)
- [x] gateway 유지 (멀티테넌시 필수, 2 replicas)
- [x] ingester replication_factor를 2로 설정 (Buzzvil 표준)

## Storage Configuration

- [x] use_thanos_objstore: true 추가
- [x] S3 버킷: ops-buzzvil-loki-v3
- [x] IAM Role: eks-loki-v3-s3-role-ops
- [x] TSDB schema v13 사용
- [x] Bloom filters 활성화

## Schema Configuration

- [x] schemaConfig from 날짜를 2025-12-02로 업데이트
- [x] TSDB store 사용
- [x] schema v13 사용

## Distributed Mode Components

- [x] ingester: 3 replicas, autoscaling 3-10
- [x] querier: 3 replicas, autoscaling 3-10
- [x] queryFrontend: 2 replicas
- [x] queryScheduler: 2 replicas
- [x] distributor: 3 replicas, autoscaling 3-10
- [x] compactor: 1 replica
- [x] indexGateway: 2 replicas
- [x] gateway: 2 replicas

## Notes for Next Steps

- [ ] Alloy agent 설정 시 multi-tenancy 고려사항 반영
- [ ] 배포 후 각 컴포넌트 상태 확인
- [ ] S3 저장 확인
- [ ] 멀티테넌시 동작 검증 (ops, dev, prod)
