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

  # NOTE: AWS Academy - Cannot use IRSA, LB Controller will use node role (LabRole)
  # In production, uncomment this to use dedicated IRSA:
  # set {
  #   name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
  #   value = aws_iam_role.aws_lb_controller[0].arn
  # }

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

  # Valores customizados para AWS Academy (recursos limitados)
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
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "1Gi"
          }
        }
      }

      # Query Service
      queryService = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }

      # Frontend
      frontend = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }

      # OTel Collector
      otelCollector = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }

      # Alertmanager
      alertmanager = {
        enabled = true
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.signoz,
  ]
}

# -----------------------------------------------------------------------------
# StorageClass para GP3 (performance melhor)
# -----------------------------------------------------------------------------
# NOTE: Commented out for AWS Academy - requires EBS CSI Driver
# resource "kubernetes_storage_class" "gp3" {
#   metadata {
#     name = "gp3"
#     annotations = {
#       "storageclass.kubernetes.io/is-default-class" = "true"
#     }
#   }
#
#   storage_provisioner    = "ebs.csi.aws.com"
#   reclaim_policy         = "Delete"
#   volume_binding_mode    = "WaitForFirstConsumer"
#   allow_volume_expansion = true
#
#   parameters = {
#     type      = "gp3"
#     encrypted = "true"
#   }
#
#   depends_on = [aws_eks_addon.ebs_csi]
# }

# Remover default da gp2
# NOTE: Commented out for AWS Academy - requires EBS CSI Driver
# resource "kubernetes_annotations" "gp2_non_default" {
#   api_version = "storage.k8s.io/v1"
#   kind        = "StorageClass"
#   metadata {
#     name = "gp2"
#   }
#   annotations = {
#     "storageclass.kubernetes.io/is-default-class" = "false"
#   }
#
#   depends_on = [kubernetes_storage_class.gp3]
# }
