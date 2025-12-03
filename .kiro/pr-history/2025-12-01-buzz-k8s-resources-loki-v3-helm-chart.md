# PR: Add Loki v3 Helm chart configuration

- Repository: Buzzvil/buzz-k8s-resources
- PR URL: https://github.com/Buzzvil/buzz-k8s-resources/pull/1447
- Created: 2025-12-01
- Updated: 2025-12-02
- Status: open

## Review 수정사항 (2025-12-02)
1. project: data-platform → devops
2. registry: docker.io → ECR pull-through cache (591756927972.dkr.ecr.ap-northeast-1.amazonaws.com/docker.io)
3. syncPolicy.syncOptions: CreateNamespace=true 추가
4. Loki 이미지 태그: 3.2.0 → 3.2.2 (최신 패치)
5. max_query_length: 721h → 168h (retention 기간과 일치)
6. max_query_lookback: 720h → 168h (retention 기간과 일치)
7. serviceMonitor 위치: 최상위 → monitoring.serviceMonitor (Loki chart v6 구조)
8. 모든 CPU/Memory 리소스 값을 문자열로 변경 (Kubernetes 표준)

## 변경 목적
Loki v3 업그레이드를 위한 ArgoCD Application 설정 추가. ops 클러스터에 Loki 3.2.0을 distributed mode로 배포하며, 멀티테넌시와 S3 백엔드를 활용한 중앙화된 로그 시스템 구축.

## 주요 설정
- Loki 3.2.0 (Helm chart v6.16.0)
- Distributed mode: ingester, querier, distributor, compactor, indexGateway 분리
- Multi-tenancy: auth_enabled=true (ops, dev, prod 테넌트 격리)
- S3 백엔드: ops-buzzvil-loki-v3
- TSDB schema v13 + Bloom filters (쿼리 성능 향상)
- IAM Role: eks-loki-v3-s3-role-ops (IRSA)
- Autoscaling: ingester/querier/distributor (3-10 replicas)
- Retention: 7일

## 관련 작업
- Terraform PR: https://github.com/Buzzvil/terraform-resource/pull/3715
- Task: loki-alloy-deployment Task 2

## Diff
```diff
diff --git a/argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml b/argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml
new file mode 100644
index 00000000..4b69aa41
--- /dev/null
+++ b/argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml
@@ -0,0 +1,190 @@
+apiVersion: argoproj.io/v1alpha1
+kind: Application
+metadata:
+  name: loki-v3-ops
+  namespace: argo-cd
+  finalizers:
+    - resources-finalizer.argocd.argoproj.io
+spec:
+  project: data-platform
+  destination:
+    namespace: loki-v3
+    server: https://kubernetes.default.svc
+  source:
+    chart: loki
+    repoURL: https://grafana.github.io/helm-charts
+    targetRevision: 6.16.0
+    helm:
+      releaseName: loki-v3
+      valuesObject:
+        deploymentMode: Distributed
+        
+        loki:
+          image:
+            registry: docker.io
+            repository: grafana/loki
+            tag: 3.2.0
+          
+          auth_enabled: true
+          
+          schemaConfig:
+            configs:
+              - from: "2024-01-01"
+                store: tsdb
+                object_store: s3
+                schema: v13
+                index:
+                  prefix: loki_v3_index_
+                  period: 24h
+          
+          ingester:
+            chunk_encoding: snappy
+            chunk_target_size: 1536000
+            chunk_idle_period: 30m
+            chunk_retain_period: 1m
+            max_chunk_age: 2h
+            wal:
+              flush_on_shutdown: true
+              dir: /var/loki/wal
+              replay_memory_ceiling: 1GB
+          
+          limits_config:
+            ingestion_rate_mb: 50
+            ingestion_burst_size_mb: 100
+            max_query_parallelism: 256
+            max_streams_per_user: 100000
+            split_queries_by_interval: 30m
+            max_query_length: 721h
+            max_query_lookback: 720h
+            retention_period: 168h
+            reject_old_samples: true
+            reject_old_samples_max_age: 168h
+          
+          storage:
+            type: s3
+            bucketNames:
+              chunks: ops-buzzvil-loki-v3
+              ruler: ops-buzzvil-loki-v3
+              admin: ops-buzzvil-loki-v3
+            s3:
+              region: ap-northeast-1
+              s3ForcePathStyle: false
+              insecure: false
+          
+          storage_config:
+            bloom_shipper:
+              enabled: true
+            tsdb_shipper:
+              active_index_directory: /var/loki/index
+              cache_location: /var/loki/index_cache
+          
+          compactor:
+            retention_enabled: true
+            delete_request_store: s3
+            working_directory: /var/loki/compactor
+        
+        serviceAccount:
+          create: true
+          annotations:
+            eks.amazonaws.com/role-arn: "arn:aws:iam::591756927972:role/eks-loki-v3-s3-role-ops"
+        
+        ingester:
+          replicas: 3
+          resources:
+            requests:
+              cpu: 2
+              memory: 4Gi
+            limits:
+              cpu: 4
+              memory: 8Gi
+          autoscaling:
+            enabled: true
+            minReplicas: 3
+            maxReplicas: 10
+            targetCPUUtilizationPercentage: 80
+            targetMemoryUtilizationPercentage: 80
+          persistence:
+            enabled: true
+            size: 50Gi
+        
+        querier:
+          replicas: 3
+          resources:
+            requests:
+              cpu: 1
+              memory: 2Gi
+            limits:
+              cpu: 2
+              memory: 4Gi
+          autoscaling:
+            enabled: true
+            minReplicas: 3
+            maxReplicas: 10
+            targetCPUUtilizationPercentage: 80
+            targetMemoryUtilizationPercentage: 80
+        
+        queryFrontend:
+          replicas: 2
+          resources:
+            requests:
+              cpu: 500m
+              memory: 1Gi
+            limits:
+              cpu: 1
+              memory: 2Gi
+        
+        distributor:
+          replicas: 3
+          resources:
+            requests:
+              cpu: 1
+              memory: 1Gi
+            limits:
+              cpu: 2
+              memory: 2Gi
+          autoscaling:
+            enabled: true
+            minReplicas: 3
+            maxReplicas: 10
+            targetCPUUtilizationPercentage: 80
+        
+        compactor:
+          replicas: 1
+          resources:
+            requests:
+              cpu: 1
+              memory: 2Gi
+            limits:
+              cpu: 2
+              memory: 4Gi
+          persistence:
+            enabled: true
+            size: 50Gi
+        
+        indexGateway:
+          replicas: 2
+          resources:
+            requests:
+              cpu: 500m
+              memory: 1Gi
+            limits:
+              cpu: 1
+              memory: 2Gi
+          persistence:
+            enabled: true
+            size: 50Gi
+        
+        gateway:
+          replicas: 2
+          resources:
+            requests:
+              cpu: 200m
+              memory: 200Mi
+            limits:
+              cpu: 500m
+              memory: 500Mi
+        
+        serviceMonitor:
+          enabled: true
+          labels:
+            release: kube-prometheus-stack
```
