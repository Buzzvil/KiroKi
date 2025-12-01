#!/bin/bash
set -e

echo "=== Loki v3 Helm Chart Validation Test ==="

CHART_FILE="/workspaces/KiroKi/buzz-k8s-resources/argo-cd/buzzvil-eks-ops/apps/loki-v3.yaml"

# Test 1: File exists
echo "Test 1: Checking if loki-v3.yaml exists..."
if [ ! -f "$CHART_FILE" ]; then
    echo "❌ FAIL: loki-v3.yaml not found"
    exit 1
fi
echo "✅ PASS: loki-v3.yaml exists"

# Test 2: Valid YAML syntax
echo "Test 2: Validating YAML syntax..."
if ! yq eval '.' "$CHART_FILE" > /dev/null 2>&1; then
    echo "❌ FAIL: Invalid YAML syntax"
    exit 1
fi
echo "✅ PASS: Valid YAML syntax"

# Test 3: Multi-tenancy enabled
echo "Test 3: Checking auth_enabled setting..."
AUTH_ENABLED=$(yq eval '.spec.source.helm.valuesObject.loki.auth_enabled' "$CHART_FILE")
if [ "$AUTH_ENABLED" != "true" ]; then
    echo "❌ FAIL: auth_enabled is not true (got: $AUTH_ENABLED)"
    exit 1
fi
echo "✅ PASS: Multi-tenancy enabled (auth_enabled: true)"

# Test 4: S3 bucket configuration
echo "Test 4: Checking S3 bucket configuration..."
BUCKET_CHUNKS=$(yq eval '.spec.source.helm.valuesObject.loki.storage.bucketNames.chunks' "$CHART_FILE")
if [ "$BUCKET_CHUNKS" != "ops-buzzvil-loki-v3" ]; then
    echo "❌ FAIL: S3 bucket name incorrect (got: $BUCKET_CHUNKS)"
    exit 1
fi
echo "✅ PASS: S3 bucket configured correctly"

# Test 5: IAM Role ARN
echo "Test 5: Checking IAM Role ARN..."
IAM_ROLE=$(yq eval '.spec.source.helm.valuesObject.serviceAccount.annotations."eks.amazonaws.com/role-arn"' "$CHART_FILE")
if [[ ! "$IAM_ROLE" =~ ^arn:aws:iam::[0-9]+:role/eks-loki-v3-s3-role-ops$ ]]; then
    echo "❌ FAIL: IAM Role ARN format incorrect (got: $IAM_ROLE)"
    exit 1
fi
echo "✅ PASS: IAM Role ARN configured correctly"

# Test 6: Distributed mode
echo "Test 6: Checking deployment mode..."
DEPLOYMENT_MODE=$(yq eval '.spec.source.helm.valuesObject.deploymentMode' "$CHART_FILE")
if [ "$DEPLOYMENT_MODE" != "Distributed" ]; then
    echo "❌ FAIL: Deployment mode is not Distributed (got: $DEPLOYMENT_MODE)"
    exit 1
fi
echo "✅ PASS: Distributed mode enabled"

# Test 7: TSDB schema
echo "Test 7: Checking TSDB schema configuration..."
SCHEMA_STORE=$(yq eval '.spec.source.helm.valuesObject.loki.schemaConfig.configs[0].store' "$CHART_FILE")
SCHEMA_VERSION=$(yq eval '.spec.source.helm.valuesObject.loki.schemaConfig.configs[0].schema' "$CHART_FILE")
if [ "$SCHEMA_STORE" != "tsdb" ] || [ "$SCHEMA_VERSION" != "v13" ]; then
    echo "❌ FAIL: TSDB schema not configured correctly (store: $SCHEMA_STORE, schema: $SCHEMA_VERSION)"
    exit 1
fi
echo "✅ PASS: TSDB schema v13 configured"

# Test 8: Bloom filters enabled
echo "Test 8: Checking Bloom filters..."
BLOOM_ENABLED=$(yq eval '.spec.source.helm.valuesObject.loki.storage_config.bloom_shipper.enabled' "$CHART_FILE")
if [ "$BLOOM_ENABLED" != "true" ]; then
    echo "❌ FAIL: Bloom filters not enabled (got: $BLOOM_ENABLED)"
    exit 1
fi
echo "✅ PASS: Bloom filters enabled"

# Test 9: Autoscaling configuration
echo "Test 9: Checking autoscaling for ingester..."
INGESTER_AUTOSCALING=$(yq eval '.spec.source.helm.valuesObject.ingester.autoscaling.enabled' "$CHART_FILE")
if [ "$INGESTER_AUTOSCALING" != "true" ]; then
    echo "❌ FAIL: Ingester autoscaling not enabled"
    exit 1
fi
echo "✅ PASS: Autoscaling configured"

# Test 10: Retention policy
echo "Test 10: Checking retention policy..."
RETENTION=$(yq eval '.spec.source.helm.valuesObject.loki.limits_config.retention_period' "$CHART_FILE")
if [ "$RETENTION" != "168h" ]; then
    echo "❌ FAIL: Retention period incorrect (got: $RETENTION, expected: 168h)"
    exit 1
fi
echo "✅ PASS: 7-day retention policy configured"

echo ""
echo "=== All Tests Passed ✅ ==="
