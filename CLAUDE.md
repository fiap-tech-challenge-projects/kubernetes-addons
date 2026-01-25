# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Note**: Do NOT add `Co-Authored-By` to commits in this project.

## Project Overview

Terraform module for installing Kubernetes addons (Phase 2) AFTER EKS cluster creation (Phase 1). This separation solves the chicken-and-egg problem with Kubernetes/Helm provider initialization.

## Common Commands

```bash
# Initialize with backend
cd terraform
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
terraform init -backend-config="bucket=fiap-tech-challenge-tf-state-${ACCOUNT_ID}"

# Deployment
terraform plan
terraform apply
terraform destroy

# Verify deployment
kubectl get namespaces
kubectl get pods -n kube-system  # Check LB controller, metrics-server
kubectl get pods -n signoz       # Check SigNoz (if enabled)
```

## Architecture

This module **depends on** `kubernetes-core-infra` (Phase 1) and reads cluster information via Terraform remote state:

```
Phase 1 (kubernetes-core-infra)
  ↓ outputs → S3 state
Phase 2 (THIS MODULE)
  ↓ reads remote state
  ↓ initializes K8s/Helm providers
  ↓ creates resources
```

## File Structure

```
terraform/
├── main.tf              # Remote state, providers
├── addons.tf            # Namespaces, Helm releases
├── variables.tf         # Input variables
├── outputs.tf           # Module outputs
└── terraform.tfvars.example
```

## Key Configuration

### Remote State (Phase 1)

```hcl
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "fiap-tech-challenge-tf-state-${account_id}"
    key    = "kubernetes-core-infra/terraform.tfstate"
  }
}
```

### Providers

```hcl
provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(...)
}

provider "helm" {
  kubernetes {
    host = data.terraform_remote_state.eks.outputs.cluster_endpoint
    # ...
  }
}
```

## What Gets Created

| Resource | Purpose | Conditional |
|----------|---------|-------------|
| `ftc-app-staging` namespace | Staging environment | Always |
| `ftc-app-production` namespace | Production environment | Always |
| AWS LB Controller (Helm) | ALB/NLB for Ingress | `enable_aws_lb_controller` |
| Metrics Server (Helm) | HPA support | Always |
| `signoz` namespace | Observability | `enable_signoz` |
| SigNoz (Helm) | OpenTelemetry stack | `enable_signoz` |

## Important Notes

### SigNoz Default OFF

SigNoz is **disabled by default** (`enable_signoz = false`) to:
- Reduce deployment time (saves ~8 minutes)
- Reduce resource usage (saves ~2GB RAM)
- Avoid timeouts on AWS Academy

Enable only when needed for observability.

### AWS Academy Limitations

- Uses `LabRole` (cannot create IRSA)
- LB Controller uses node role instead of dedicated IRSA
- No EBS CSI Driver (uses default gp2)

### No depends_on for aws_eks_node_group

Resources in this module **cannot** reference Phase 1 resources directly (different state). Dependencies are implicit via:
1. Remote state read (ensures Phase 1 completed)
2. Provider initialization (requires cluster endpoint)
3. Kubernetes API calls (require accessible cluster)

## Dependencies

**Required before deployment:**
1. `kubernetes-core-infra` (Phase 1) deployed
2. EKS cluster accessible via kubectl
3. S3 backend bucket exists
4. AWS credentials configured

**Consumed by:**
- `k8s-main-service` - deploys to `ftc-app-*` namespaces
- Application observability - sends traces to SigNoz

## Troubleshooting

### "No configuration has been provided"
**Cause**: Phase 1 not completed
**Fix**: Deploy `kubernetes-core-infra` first

### "Error: Kubernetes cluster unreachable"
**Cause**: Invalid kubeconfig or cluster not ready
**Fix**: Run `aws eks update-kubeconfig --region us-east-1 --name <cluster-name>`

### Helm timeout
**Cause**: Insufficient cluster resources or slow image pulls
**Fix**: Check node status with `kubectl get nodes` and `kubectl describe nodes`

### SigNoz pods pending
**Cause**: No persistent volume available (EBS CSI issue)
**Fix**: AWS Academy - SigNoz not fully supported, set `enable_signoz = false`

## Deployment Time

- Namespaces: instant
- AWS LB Controller: 2-3 minutes
- Metrics Server: 1 minute
- SigNoz (optional): 8-10 minutes

**Total**: 3-14 minutes

## Terraform Backend

- **S3 Bucket**: `fiap-tech-challenge-tf-state-{account_id}`
- **State Key**: `kubernetes-addons/terraform.tfstate`
- **DynamoDB Lock**: `fiap-terraform-locks`

## Related Documentation

- [README.md](./README.md) - Full usage guide
- [kubernetes-core-infra](../kubernetes-core-infra/README.md) - Phase 1
- [HashiCorp EKS Tutorial](https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks) - Pattern explanation
