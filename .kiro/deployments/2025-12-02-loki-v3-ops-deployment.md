# Loki v3 Deployment to ops Cluster

- Date: 2025-12-02
- Deployment: #4325
- Environment: buzzvil-eks-ops
- Repository: Buzzvil/buzz-k8s-resources
- Branch: feat/loki-v3-helm-chart
- Commit: 008275e04fe0c4116dc2a0191556821faa833211
- Gitploy URL: https://gitploy.buzzvil.dev/repos/Buzzvil/buzz-k8s-resources/deployments/4325

## Deployment Details

**Application**: loki-v3
**Namespace**: loki-v3
**Helm Chart**: grafana/loki v6.16.0
**Loki Version**: 3.2.2

## Configuration Highlights

### Multi-tenancy
- auth_enabled: true
- Tenants: ops, dev, prod
- Gateway enabled for tenant routing

### Storage
- S3 Backend: ops-buzzvil-loki-v3
- IAM Role: eks-loki-v3-s3-role-ops (IRSA)
- TSDB schema v13
- Bloom filters enabled
- use_thanos_objstore: true

### Optimization
- Chunk encoding: zstd (cost optimization)
- Replication factor: 2
- Retention: 168h (7 days)
- Query limits: 168h (aligned with retention)

### Components
- Ingester: 3 replicas (autoscaling 3-10)
- Querier: 3 replicas (autoscaling 3-10)
- QueryFrontend: 2 replicas
- QueryScheduler: 2 replicas
- Distributor: 3 replicas (autoscaling 3-10)
- Compactor: 1 replica (500m/1Gi)
- IndexGateway: 2 replicas
- Gateway: 2 replicas

## Deployment Status

### Initial Deployment (#4325)
- Created: 2025-12-02T02:01:17Z
- Status: success
- Commit: 008275e04fe0c4116dc2a0191556821faa833211

### Configuration Fixes

#### Issue 1: Missing maxUnavailable for PodDisruptionBudget
- Deployment #4326: Added queryFrontend.maxUnavailable
- Commit: 4d9f1674e766ccaf4a69e4cbccd95d4507c7d418

#### Issue 2: Missing maxUnavailable for all multi-replica components
- Deployment #4327: Added maxUnavailable to querier, queryScheduler, distributor, indexGateway, gateway, ingester
- Commit: 9c54f5087a77dd1b9d835583af9ffde7ccfadec0

#### Issue 3: SimpleScalable components conflict with Distributed mode
- Deployment #4328: Disabled backend, read, write, singleBinary components
- Commit: 5b62af84e766ccaf4a69e4cbccd95d4507c7d418
- Status: success
- ArgoCD Status: OutOfSync (ready to sync)

## Current Status

- **Gitploy**: All deployments successful
- **ArgoCD**: Manifest generation successful, OutOfSync (awaiting sync)
- **Resources**: 52 resources ready to be created
- **Health**: Missing (resources not yet deployed)

## Next Steps

1. ✅ Gitploy deployment - COMPLETED
2. ✅ ArgoCD manifest validation - COMPLETED
3. ⏳ ArgoCD sync - PENDING (manual sync required)
4. ⏳ Verify pod status: `kubectl get pods -n loki-v3`
5. ⏳ Check Loki health: `kubectl port-forward -n loki-v3 svc/loki-v3-gateway 3100:80`
6. ⏳ Test multi-tenancy with different X-Scope-OrgID headers
7. ⏳ Verify S3 storage
8. ⏳ Check ServiceMonitor and Prometheus scraping
