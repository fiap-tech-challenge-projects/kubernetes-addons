# =============================================================================
# Kubernetes Addons (Phase 2)
# =============================================================================
# Configura addons adicionais: Namespaces, AWS Load Balancer Controller, SigNoz
# Este arquivo e aplicado APOS a criacao do cluster EKS (Phase 1)
# =============================================================================

# -----------------------------------------------------------------------------
# Namespace para Aplicacao - Staging (Homologacao)
# -----------------------------------------------------------------------------

resource "kubernetes_namespace" "staging" {
  metadata {
    name = "${var.app_namespace}-staging"

    labels = {
      name        = "${var.app_namespace}-staging"
      environment = "staging"
      managed-by  = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Namespace para Aplicacao - Production
# -----------------------------------------------------------------------------

resource "kubernetes_namespace" "production" {
  metadata {
    name = "${var.app_namespace}-production"

    labels = {
      name        = "${var.app_namespace}-production"
      environment = "production"
      managed-by  = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller
# -----------------------------------------------------------------------------

resource "helm_release" "aws_lb_controller" {
  count = var.enable_aws_lb_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_lb_controller_version
  namespace  = "kube-system"

  # CRITICAL: Extended timeouts for webhook initialization
  timeout         = 900 # 15 minutes (increased from default 300s)
  wait            = true
  wait_for_jobs   = true
  atomic          = false # Prevent rollback loops on timeout
  cleanup_on_fail = false # Keep resources for debugging

  # Force dependency on namespaces to ensure they exist first
  depends_on = [
    kubernetes_namespace.staging,
    kubernetes_namespace.production
  ]

  set {
    name  = "clusterName"
    value = local.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  # Production: Use dedicated IRSA role for AWS Load Balancer Controller
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = local.aws_lb_controller_role_arn
  }
  # AWS ACADEMY: Comment out the IRSA annotation above - LB Controller will use node role (LabRole)

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = local.vpc_id
  }

  # CRITICAL FIX: Reduce replicas to 1 for resource-constrained environments
  # Default is 2 replicas which causes "Insufficient memory, Too many pods" errors
  set {
    name  = "replicaCount"
    value = "1"
  }

  # Resource requests for controller pods - BALANCED for t3.large
  set {
    name  = "resources.requests.cpu"
    value = "100m" # Sufficient for AWS API calls
  }

  set {
    name  = "resources.requests.memory"
    value = "128Mi" # Balanced for webhook operations
  }

  set {
    name  = "resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "resources.limits.memory"
    value = "256Mi"
  }

  # Enable logging for troubleshooting
  set {
    name  = "logLevel"
    value = "info"
  }
}

# -----------------------------------------------------------------------------
# Wait for AWS LB Controller Webhook to be Ready
# -----------------------------------------------------------------------------
# CRITICAL: AWS Load Balancer Controller webhook takes time to initialize
# This prevents "no endpoints available for service" errors

resource "time_sleep" "wait_for_lb_controller" {
  count = var.enable_aws_lb_controller ? 1 : 0

  create_duration = "90s" # Wait 90 seconds for webhook pods to be fully ready

  depends_on = [
    helm_release.aws_lb_controller
  ]
}

# -----------------------------------------------------------------------------
# Metrics Server (para HPA)
# -----------------------------------------------------------------------------
# DISABLED for Free Tier: Causes context deadline exceeded on t3.micro
# Metrics Server only needed for HPA (Horizontal Pod Autoscaler)
# Free Tier clusters don't have resources for autoscaling

resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.11.0"
  namespace  = "kube-system"

  timeout         = 600 # 10 minutes for Free Tier t3.micro
  wait            = true
  wait_for_jobs   = true
  atomic          = false # Prevent rollback loops on timeout
  cleanup_on_fail = false # Keep resources for debugging

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  # FREE TIER: Reduce resource requests for t3.micro (1GB RAM)
  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "resources.limits.memory"
    value = "128Mi"
  }
}

# -----------------------------------------------------------------------------
# External Secrets Operator (REQUIRED per PHASE-3 plan)
# -----------------------------------------------------------------------------
# Syncs secrets from AWS Secrets Manager to Kubernetes Secrets
# Required by k8s-main-service for DATABASE_URL, JWT_SECRET, etc.

resource "helm_release" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.external_secrets_version
  namespace        = "external-secrets-system"
  create_namespace = true

  timeout         = 900 # 15 minutes (increased from 10min due to CRD installation)
  wait            = true
  wait_for_jobs   = true
  atomic          = false # Prevent rollback loops on timeout
  cleanup_on_fail = false # Keep resources for debugging

  # CRITICAL: Must wait for AWS LB Controller webhook to be fully ready
  depends_on = [
    helm_release.aws_lb_controller,
    time_sleep.wait_for_lb_controller
  ]

  # Install CRDs (SecretStore, ExternalSecret, etc.)
  set {
    name  = "installCRDs"
    value = "true"
  }

  # Reduce replicas for resource-constrained environments
  set {
    name  = "replicaCount"
    value = "1"
  }

  # Controller resources (main operator) - BALANCED for t3.large
  set {
    name  = "resources.requests.cpu"
    value = "100m" # Sufficient for secret synchronization
  }

  set {
    name  = "resources.requests.memory"
    value = "128Mi" # Adequate for operator workload
  }

  set {
    name  = "resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "resources.limits.memory"
    value = "256Mi"
  }

  # Reduce webhook replicas
  set {
    name  = "webhook.replicaCount"
    value = "1"
  }

  # Webhook resources (validates ExternalSecret CRDs) - BALANCED
  set {
    name  = "webhook.resources.requests.cpu"
    value = "50m" # Adequate for validation webhooks
  }

  set {
    name  = "webhook.resources.requests.memory"
    value = "64Mi" # Sufficient for webhook operations
  }

  set {
    name  = "webhook.resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "webhook.resources.limits.memory"
    value = "128Mi"
  }

  # Cert controller resources (manages webhook certificates) - BALANCED
  set {
    name  = "certController.resources.requests.cpu"
    value = "50m" # Adequate for cert management
  }

  set {
    name  = "certController.resources.requests.memory"
    value = "64Mi" # Sufficient for TLS operations
  }

  set {
    name  = "certController.resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "certController.resources.limits.memory"
    value = "128Mi"
  }

  # Service account for IRSA (IAM Roles for Service Accounts)
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-secrets"
  }
}

# -----------------------------------------------------------------------------
# Wait for External Secrets Webhook to be Ready
# -----------------------------------------------------------------------------
# External Secrets also has webhook validations that need to be ready

resource "time_sleep" "wait_for_external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  create_duration = "60s" # Wait 60 seconds for webhook pods to be fully ready

  depends_on = [
    helm_release.external_secrets
  ]
}

# -----------------------------------------------------------------------------
# SigNoz Namespace
# -----------------------------------------------------------------------------

resource "kubernetes_namespace" "signoz" {
  count = var.enable_signoz ? 1 : 0

  metadata {
    name = var.signoz_namespace

    labels = {
      name       = var.signoz_namespace
      purpose    = "observability"
      managed-by = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# SigNoz via Helm
# -----------------------------------------------------------------------------

resource "helm_release" "signoz" {
  count = var.enable_signoz ? 1 : 0

  name       = "signoz"
  repository = "https://charts.signoz.io"
  chart      = "signoz"
  version    = var.signoz_chart_version
  namespace  = var.signoz_namespace

  # CRITICAL: SigNoz is heavy - needs extended timeout
  timeout         = 1200 # 20 minutes (ClickHouse StatefulSets are slow)
  wait            = true
  wait_for_jobs   = true
  atomic          = false # Prevent rollback loops on timeout
  cleanup_on_fail = false # Keep resources for debugging

  # Must wait for all previous stages (webhooks must be ready)
  depends_on = [
    kubernetes_namespace.signoz,
    helm_release.aws_lb_controller,
    time_sleep.wait_for_lb_controller,
    helm_release.external_secrets,
    time_sleep.wait_for_external_secrets,
    kubernetes_storage_class.gp3
  ]

  # Production configuration with adequate resources
  values = [
    yamlencode({
      # ClickHouse configuration - BALANCED for t3.large staging
      clickhouse = {
        persistence = {
          enabled = true
          size    = var.signoz_storage_size
        }
        resources = {
          requests = {
            cpu    = "500m" # Staging: 0.5 CPU (reduced from 1000m)
            memory = "1Gi"  # Staging: 1GB (reduced from 4Gi)
          }
          limits = {
            cpu    = "1000m" # Staging: up to 1 CPU (reduced from 2000m)
            memory = "2Gi"   # Staging: up to 2GB (reduced from 8Gi)
          }
        }
      }

      # Query Service - BALANCED for t3.large staging
      queryService = {
        resources = {
          requests = {
            cpu    = "200m"  # Staging: 0.2 CPU (reduced from 500m)
            memory = "256Mi" # Staging: 256MB (reduced from 1Gi)
          }
          limits = {
            cpu    = "500m"  # Staging: up to 0.5 CPU (reduced from 1000m)
            memory = "512Mi" # Staging: up to 512MB (reduced from 2Gi)
          }
        }
      }

      # Frontend - BALANCED for t3.large staging
      frontend = {
        resources = {
          requests = {
            cpu    = "100m"  # Staging: 0.1 CPU (reduced from 200m)
            memory = "128Mi" # Staging: 128MB (reduced from 512Mi)
          }
          limits = {
            cpu    = "200m"  # Staging: up to 0.2 CPU (reduced from 500m)
            memory = "256Mi" # Staging: up to 256MB (reduced from 1Gi)
          }
        }
      }

      # OTel Collector - BALANCED for t3.large staging
      otelCollector = {
        resources = {
          requests = {
            cpu    = "200m"  # Staging: 0.2 CPU (reduced from 500m)
            memory = "256Mi" # Staging: 256MB (reduced from 1Gi)
          }
          limits = {
            cpu    = "500m"  # Staging: up to 0.5 CPU (reduced from 1000m)
            memory = "512Mi" # Staging: up to 512MB (reduced from 2Gi)
          }
        }
      }

      # Alertmanager - BALANCED for t3.large staging
      alertmanager = {
        enabled = true
        resources = {
          requests = {
            cpu    = "50m"  # Staging: 0.05 CPU (reduced from 100m)
            memory = "64Mi" # Staging: 64MB (reduced from 256Mi)
          }
          limits = {
            cpu    = "100m"  # Staging: up to 0.1 CPU (reduced from 200m)
            memory = "128Mi" # Staging: up to 128MB (reduced from 512Mi)
          }
        }
      }
    })
  ]
}

# -----------------------------------------------------------------------------
# StorageClass para GP3 (performance melhor que GP2)
# -----------------------------------------------------------------------------
# Production: Use GP3 as default storage class (better performance/cost ratio)
# Requires EBS CSI Driver addon to be enabled in kubernetes-core-infra

resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }
}

# Remove default annotation from gp2
resource "kubernetes_annotations" "gp2_non_default" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"

  metadata {
    name = "gp2"
  }

  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }

  depends_on = [kubernetes_storage_class.gp3]
}

# =============================================================================
# AWS ACADEMY VERSION (COMMENTED OUT)
# =============================================================================
# AWS Academy: EBS CSI Driver may cause timeout issues without proper IRSA
# If you need to disable GP3 storage class, comment out the resources above
# and the cluster will use the default GP2 storage class
