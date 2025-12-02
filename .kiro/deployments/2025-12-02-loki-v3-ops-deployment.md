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

- Created: 2025-12-02T02:01:17Z
- Status: created
- GitHub Deployment: https://github.com/Buzzvil/buzz-k8s-resources/commit/008275e04fe0c4116dc2a0191556821faa833211

## Next Steps

1. Monitor deployment status via Gitploy
2. Check ArgoCD sync status
3. Verify pod status: `kubectl get pods -n loki-v3`
4. Check Loki health: `kubectl port-forward -n loki-v3 svc/loki-v3-gateway 3100:80`
5. Test multi-tenancy with different X-Scope-OrgID headers
6. Verify S3 storage
7. Check ServiceMonitor and Prometheus scraping
