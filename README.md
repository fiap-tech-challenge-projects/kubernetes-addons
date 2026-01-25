# Kubernetes Addons (Phase 2)

## Overview

This Terraform module installs Kubernetes addons and resources AFTER the EKS cluster has been created by `kubernetes-core-infra` (Phase 1). This separation solves the chicken-and-egg problem where Kubernetes/Helm providers cannot initialize before the cluster exists.

## Problem Solved

**Before** (Single State):
```
terraform plan
├─ Initialize providers (kubernetes/helm) → FAIL (cluster doesn't exist yet)
└─ Create EKS cluster → Never reached
```

**After** (Two States):
```
Phase 1 (kubernetes-core-infra):
terraform plan
├─ Initialize providers (only AWS) → SUCCESS
└─ Create EKS cluster → SUCCESS

Phase 2 (kubernetes-addons):
terraform plan
├─ Read cluster info from remote state → SUCCESS
├─ Initialize providers (kubernetes/helm) → SUCCESS
└─ Create namespaces, Helm releases → SUCCESS
```

## What Gets Created

### Namespaces
- `ftc-app-staging` - Staging application environment
- `ftc-app-production` - Production application environment
- `signoz` - Observability stack (if enabled)

### Helm Releases
- **AWS Load Balancer Controller** - ALB/NLB integration for Ingress
- **Metrics Server** - Required for HPA (Horizontal Pod Autoscaler)
- **SigNoz** - OpenTelemetry observability stack (optional)

## Prerequisites

1. **Phase 1 must be completed**: EKS cluster must exist
2. **Terraform backend configured**: S3 bucket and DynamoDB table
3. **AWS credentials**: Same as used for Phase 1

## Usage

### Manual Deployment

```bash
cd terraform

# Initialize (configure backend with your account ID)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
terraform init -backend-config="bucket=fiap-tech-challenge-tf-state-${ACCOUNT_ID}"

# Create tfvars from example
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings

# Plan
terraform plan

# Apply
terraform apply
```

### Via CI/CD

The `infra-orchestrator` workflow automatically deploys both phases:

```bash
# In infra-orchestrator repo
gh workflow run deploy-all.yml --field environment=staging
```

## Configuration

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `environment` | Environment (staging/production) | `development` |
| `app_namespace` | Base namespace name | `ftc-app` |
| `enable_aws_lb_controller` | Install ALB Controller | `true` |
| `enable_signoz` | Install SigNoz | `false` |
| `signoz_storage_size` | ClickHouse storage | `20Gi` |

### Enabling SigNoz

SigNoz is **disabled by default** to reduce deployment time and resource usage. To enable:

```hcl
enable_signoz = true
```

**Note**: SigNoz requires:
- 2 vCPU total across all pods
- 2.5 GB RAM
- 20 GB persistent storage
- ~5-10 minutes to deploy

## Outputs

After deployment, outputs include:

```bash
terraform output staging_namespace      # ftc-app-staging
terraform output production_namespace   # ftc-app-production
terraform output signoz_otel_endpoint   # signoz-otel-collector.signoz.svc.cluster.local:4317
```

## Troubleshooting

### Error: "No configuration has been provided"

**Cause**: Phase 1 (kubernetes-core-infra) not completed yet.

**Solution**: Deploy Phase 1 first:
```bash
cd ../kubernetes-core-infra/terraform
terraform apply
```

### Error: "Cluster unreachable"

**Cause**: kubectl not configured or cluster not accessible.

**Solution**: Configure kubectl:
```bash
aws eks update-kubeconfig --region us-east-1 --name fiap-tech-challenge-eks-staging
kubectl get nodes  # Verify access
```

### Helm Release Fails

**Cause**: Nodes not ready or insufficient resources.

**Solution**:
```bash
kubectl get nodes  # Check node status
kubectl describe nodes  # Check resource allocations
```

## Architecture

```
┌─────────────────────────────────────────┐
│  Phase 1: kubernetes-core-infra         │
│  ├─ VPC, Subnets, NAT Gateway           │
│  ├─ EKS Cluster                         │
│  ├─ Node Group (t3.medium x2)           │
│  └─ IAM Roles (LabRole)                 │
└─────────────────┬───────────────────────┘
                  │ (outputs saved to S3)
                  ▼
┌─────────────────────────────────────────┐
│  Phase 2: kubernetes-addons (THIS)      │
│  ├─ Read remote state from S3           │
│  ├─ Initialize K8s/Helm providers       │
│  ├─ Create Namespaces                   │
│  ├─ Install AWS LB Controller           │
│  ├─ Install Metrics Server              │
│  └─ Install SigNoz (optional)           │
└─────────────────────────────────────────┘
```

## Dependencies

| Phase 1 Output | Used For |
|----------------|----------|
| `cluster_endpoint` | Kubernetes provider configuration |
| `cluster_certificate_authority` | Kubernetes authentication |
| `cluster_name` | Helm chart cluster identification |
| `vpc_id` | AWS LB Controller VPC configuration |

## Deployment Time

- **AWS LB Controller**: ~2 minutes
- **Metrics Server**: ~1 minute
- **SigNoz** (if enabled): ~8 minutes
- **Total**: 3-11 minutes (depending on SigNoz)

## Cost Impact

| Resource | Monthly Cost |
|----------|-------------|
| Namespaces | $0 |
| AWS LB Controller | $0 (only charges when ALB created) |
| Metrics Server | $0 |
| SigNoz (ClickHouse PV) | ~$2 (20GB EBS) |

**Total**: ~$0-2/month

## Related Modules

1. **kubernetes-core-infra** (Phase 1) - Creates EKS cluster
2. **database-managed-infra** - Creates RDS database
3. **k8s-main-service** - Deploys application to namespaces
4. **lambda-api-handler** - API Gateway + Lambda auth

## References

- [HashiCorp EKS Tutorial](https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks) - Provider Split Pattern
- [AWS Load Balancer Controller Docs](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [SigNoz Helm Chart](https://github.com/SigNoz/charts)
