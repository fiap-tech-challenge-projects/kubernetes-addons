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
}

# -----------------------------------------------------------------------------
# Metrics Server (para HPA)
# -----------------------------------------------------------------------------

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.11.0"
  namespace  = "kube-system"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
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

  # Production configuration with adequate resources
  values = [
    yamlencode({
      # ClickHouse configuration
      clickhouse = {
        persistence = {
          enabled = true
          size    = var.signoz_storage_size
        }
        resources = {
          requests = {
            cpu    = "1000m"  # Production: 1 CPU guaranteed
            memory = "4Gi"    # Production: 4GB guaranteed
          }
          limits = {
            cpu    = "2000m"  # Production: up to 2 CPU
            memory = "8Gi"    # Production: up to 8GB
          }
        }
      }
      # AWS ACADEMY: Use reduced resources to fit in t3.medium nodes
      # clickhouse.resources.requests: cpu="100m", memory="256Mi"
      # clickhouse.resources.limits: cpu="500m", memory="1Gi"

      # Query Service
      queryService = {
        resources = {
          requests = {
            cpu    = "500m"   # Production: 0.5 CPU
            memory = "1Gi"    # Production: 1GB
          }
          limits = {
            cpu    = "1000m"  # Production: up to 1 CPU
            memory = "2Gi"    # Production: up to 2GB
          }
        }
      }
      # AWS ACADEMY: Use cpu="100m", memory="256Mi" (requests) and cpu="500m", memory="512Mi" (limits)

      # Frontend
      frontend = {
        resources = {
          requests = {
            cpu    = "200m"   # Production: 0.2 CPU
            memory = "512Mi"  # Production: 512MB
          }
          limits = {
            cpu    = "500m"   # Production: up to 0.5 CPU
            memory = "1Gi"    # Production: up to 1GB
          }
        }
      }
      # AWS ACADEMY: Use cpu="50m", memory="128Mi" (requests) and cpu="200m", memory="256Mi" (limits)

      # OTel Collector
      otelCollector = {
        resources = {
          requests = {
            cpu    = "500m"   # Production: 0.5 CPU
            memory = "1Gi"    # Production: 1GB
          }
          limits = {
            cpu    = "1000m"  # Production: up to 1 CPU
            memory = "2Gi"    # Production: up to 2GB
          }
        }
      }
      # AWS ACADEMY: Use cpu="100m", memory="256Mi" (requests) and cpu="500m", memory="512Mi" (limits)

      # Alertmanager
      alertmanager = {
        enabled = true
        resources = {
          requests = {
            cpu    = "100m"   # Production: 0.1 CPU
            memory = "256Mi"  # Production: 256MB
          }
          limits = {
            cpu    = "200m"   # Production: up to 0.2 CPU
            memory = "512Mi"  # Production: up to 512MB
          }
        }
      }
      # AWS ACADEMY: Use cpu="50m", memory="64Mi" (requests) and cpu="100m", memory="128Mi" (limits)
    })
  ]

  depends_on = [
    kubernetes_namespace.signoz,
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
