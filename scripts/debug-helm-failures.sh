#!/bin/bash
# =============================================================================
# Debug Helm Release Failures in EKS
# =============================================================================
# This script helps diagnose "failed status" Helm releases with no specific error
# Use this BEFORE attempting to fix the Terraform configuration
# =============================================================================

set -e

CLUSTER_NAME="${CLUSTER_NAME:-ftc-eks-development}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "============================================================================="
echo "Helm Release Failure Debugging Script"
echo "============================================================================="
echo "Cluster: $CLUSTER_NAME"
echo "Region: $AWS_REGION"
echo ""

# -----------------------------------------------------------------------------
# 1. Check Cluster Connectivity
# -----------------------------------------------------------------------------
echo "[1/9] Checking cluster connectivity..."
if ! aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" &>/dev/null; then
    echo "ERROR: Cannot connect to cluster $CLUSTER_NAME"
    exit 1
fi

aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION" --alias "$CLUSTER_NAME" 2>/dev/null
echo "✓ Connected to cluster"
echo ""

# -----------------------------------------------------------------------------
# 2. Check Node Resources
# -----------------------------------------------------------------------------
echo "[2/9] Checking node resources (CPU/Memory)..."
echo ""
kubectl top nodes 2>/dev/null || echo "WARNING: Metrics server not available"
echo ""

kubectl describe nodes | grep -A 5 "Allocated resources:" | head -30
echo ""

# -----------------------------------------------------------------------------
# 3. Check Failed Pods
# -----------------------------------------------------------------------------
echo "[3/9] Checking for failed/pending pods..."
echo ""

FAILED_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null | tail -n +2)
if [ -n "$FAILED_PODS" ]; then
    echo "$FAILED_PODS"
    echo ""
else
    echo "✓ No failed pods found"
fi
echo ""

# -----------------------------------------------------------------------------
# 4. Check Helm Releases
# -----------------------------------------------------------------------------
echo "[4/9] Checking Helm releases..."
echo ""

helm list --all-namespaces 2>/dev/null || echo "No Helm releases found"
echo ""

# -----------------------------------------------------------------------------
# 5. Check AWS Load Balancer Controller
# -----------------------------------------------------------------------------
echo "[5/9] Checking AWS Load Balancer Controller..."
echo ""

if kubectl get deployment aws-load-balancer-controller -n kube-system &>/dev/null; then
    echo "--- Deployment Status ---"
    kubectl get deployment aws-load-balancer-controller -n kube-system
    echo ""
    
    echo "--- Pod Status ---"
    kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
    echo ""
    
    echo "--- Recent Logs ---"
    kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50 --prefix 2>/dev/null || echo "No logs available"
    echo ""
else
    echo "AWS Load Balancer Controller not found"
fi
echo ""

# -----------------------------------------------------------------------------
# 6. Check IAM Configuration
# -----------------------------------------------------------------------------
echo "[6/9] Checking IAM/IRSA configuration..."
echo ""

OIDC_PROVIDER=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query "cluster.identity.oidc.issuer" --output text 2>/dev/null | sed -e "s/^https:\/\///")
if [ -n "$OIDC_PROVIDER" ]; then
    echo "✓ OIDC Provider: $OIDC_PROVIDER"
else
    echo "WARNING: No OIDC Provider configured"
fi
echo ""

echo "--- ServiceAccount Annotations ---"
kubectl get sa aws-load-balancer-controller -n kube-system -o jsonpath='{.metadata.annotations}' 2>/dev/null || echo "SA not found"
echo ""
echo ""

echo "============================================================================="
echo "DEBUGGING COMPLETE"
echo "============================================================================="
