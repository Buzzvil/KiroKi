#!/bin/bash
set -e

echo "=== Loki v3 Review Items Validation ==="

CHART_FILE="/workspaces/KiroKi/buzz-k8s-resources/argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml"

# Test 1: Project setting
echo "Test 1: Checking project setting..."
PROJECT=$(yq eval '.spec.project' "$CHART_FILE")
if [ "$PROJECT" != "devops" ]; then
    echo "❌ FAIL: Project is not devops (got: $PROJECT)"
    exit 1
fi
echo "✅ PASS: Project is devops"

# Test 2: ECR registry
echo "Test 2: Checking ECR pull-through cache..."
REGISTRY=$(yq eval '.spec.source.helm.valuesObject.loki.image.registry' "$CHART_FILE")
if [[ ! "$REGISTRY" =~ ^591756927972\.dkr\.ecr\.ap-northeast-1\.amazonaws\.com/docker\.io$ ]]; then
    echo "❌ FAIL: ECR registry not configured (got: $REGISTRY)"
    exit 1
fi
echo "✅ PASS: ECR pull-through cache configured"

# Test 3: syncPolicy
echo "Test 3: Checking syncPolicy..."
SYNC_OPTION=$(yq eval '.spec.syncPolicy.syncOptions[0]' "$CHART_FILE")
if [ "$SYNC_OPTION" != "CreateNamespace=true" ]; then
    echo "❌ FAIL: CreateNamespace not set"
    exit 1
fi
echo "✅ PASS: syncPolicy configured"

# Test 4: Loki version
echo "Test 4: Checking Loki version..."
LOKI_TAG=$(yq eval '.spec.source.helm.valuesObject.loki.image.tag' "$CHART_FILE")
if [ "$LOKI_TAG" != "3.2.2" ]; then
    echo "❌ FAIL: Loki version not 3.2.2 (got: $LOKI_TAG)"
    exit 1
fi
echo "✅ PASS: Loki 3.2.2 configured"

# Test 5: Query limits
echo "Test 5: Checking query limits..."
MAX_QUERY_LENGTH=$(yq eval '.spec.source.helm.valuesObject.loki.limits_config.max_query_length' "$CHART_FILE")
MAX_QUERY_LOOKBACK=$(yq eval '.spec.source.helm.valuesObject.loki.limits_config.max_query_lookback' "$CHART_FILE")
if [ "$MAX_QUERY_LENGTH" != "168h" ] || [ "$MAX_QUERY_LOOKBACK" != "168h" ]; then
    echo "❌ FAIL: Query limits not 168h"
    exit 1
fi
echo "✅ PASS: Query limits match retention (168h)"

# Test 6: Chunk encoding
echo "Test 6: Checking chunk encoding..."
CHUNK_ENCODING=$(yq eval '.spec.source.helm.valuesObject.loki.ingester.chunk_encoding' "$CHART_FILE")
if [ "$CHUNK_ENCODING" != "zstd" ]; then
    echo "❌ FAIL: Chunk encoding not zstd (got: $CHUNK_ENCODING)"
    exit 1
fi
echo "✅ PASS: zstd encoding configured"

# Test 7: Replication factor
echo "Test 7: Checking replication factor..."
REPLICATION=$(yq eval '.spec.source.helm.valuesObject.loki.ingester.replication_factor' "$CHART_FILE")
if [ "$REPLICATION" != "2" ]; then
    echo "❌ FAIL: Replication factor not 2 (got: $REPLICATION)"
    exit 1
fi
echo "✅ PASS: Replication factor is 2"

# Test 8: QueryScheduler
echo "Test 8: Checking queryScheduler..."
QS_REPLICAS=$(yq eval '.spec.source.helm.valuesObject.queryScheduler.replicas' "$CHART_FILE")
if [ "$QS_REPLICAS" != "2" ]; then
    echo "❌ FAIL: QueryScheduler not configured"
    exit 1
fi
echo "✅ PASS: QueryScheduler configured"

# Test 9: Gateway
echo "Test 9: Checking gateway..."
GATEWAY_REPLICAS=$(yq eval '.spec.source.helm.valuesObject.gateway.replicas' "$CHART_FILE")
if [ "$GATEWAY_REPLICAS" != "2" ]; then
    echo "❌ FAIL: Gateway not configured"
    exit 1
fi
echo "✅ PASS: Gateway configured (multi-tenancy)"

# Test 10: use_thanos_objstore
echo "Test 10: Checking use_thanos_objstore..."
USE_THANOS=$(yq eval '.spec.source.helm.valuesObject.loki.storage_config.aws.use_thanos_objstore' "$CHART_FILE")
if [ "$USE_THANOS" != "true" ]; then
    echo "❌ FAIL: use_thanos_objstore not enabled"
    exit 1
fi
echo "✅ PASS: use_thanos_objstore enabled"

# Test 11: Schema from date
echo "Test 11: Checking schema from date..."
SCHEMA_FROM=$(yq eval '.spec.source.helm.valuesObject.loki.schemaConfig.configs[0].from' "$CHART_FILE")
if [ "$SCHEMA_FROM" != "2025-12-02" ]; then
    echo "❌ FAIL: Schema from date not updated (got: $SCHEMA_FROM)"
    exit 1
fi
echo "✅ PASS: Schema from date is current"

# Test 12: Chunk idle period
echo "Test 12: Checking chunk_idle_period..."
CHUNK_IDLE=$(yq eval '.spec.source.helm.valuesObject.loki.ingester.chunk_idle_period' "$CHART_FILE")
if [ "$CHUNK_IDLE" != "168h" ]; then
    echo "❌ FAIL: chunk_idle_period not 168h (got: $CHUNK_IDLE)"
    exit 1
fi
echo "✅ PASS: chunk_idle_period matches retention"

# Test 13: Compactor resources
echo "Test 13: Checking compactor resources..."
COMPACTOR_CPU=$(yq eval '.spec.source.helm.valuesObject.compactor.resources.requests.cpu' "$CHART_FILE")
if [ "$COMPACTOR_CPU" != "500m" ]; then
    echo "❌ FAIL: Compactor CPU not optimized (got: $COMPACTOR_CPU)"
    exit 1
fi
echo "✅ PASS: Compactor resources optimized"

# Test 14: ServiceMonitor location
echo "Test 14: Checking ServiceMonitor location..."
SM_ENABLED=$(yq eval '.spec.source.helm.valuesObject.monitoring.serviceMonitor.enabled' "$CHART_FILE")
if [ "$SM_ENABLED" != "true" ]; then
    echo "❌ FAIL: ServiceMonitor not in monitoring section"
    exit 1
fi
echo "✅ PASS: ServiceMonitor in correct location"

# Test 15: Resource string format (check YAML source directly)
echo "Test 15: Checking resource value format..."
if ! grep -q 'cpu: "' "$CHART_FILE"; then
    echo "❌ FAIL: CPU values not in string format"
    exit 1
fi
echo "✅ PASS: Resource values in string format"

echo ""
echo "=== All Review Items Validated ✅ ==="
