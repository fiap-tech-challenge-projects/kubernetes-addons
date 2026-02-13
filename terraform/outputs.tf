# =============================================================================
# Outputs - Kubernetes Addons (Phase 2)
# =============================================================================

# -----------------------------------------------------------------------------
# Namespace Outputs
# -----------------------------------------------------------------------------

output "development_namespace" {
  description = "Namespace da aplicacao - Development"
  value       = kubernetes_namespace.development.metadata[0].name
}

output "production_namespace" {
  description = "Namespace da aplicacao - Production"
  value       = kubernetes_namespace.production.metadata[0].name
}

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller
# -----------------------------------------------------------------------------

output "aws_lb_controller_status" {
  description = "Status do AWS Load Balancer Controller"
  value       = var.enable_aws_lb_controller ? "Instalado" : "Desabilitado"
}

# -----------------------------------------------------------------------------
# External Secrets Operator
# -----------------------------------------------------------------------------

output "external_secrets_status" {
  description = "Status do External Secrets Operator"
  value       = var.enable_external_secrets ? "Instalado (v${var.external_secrets_version})" : "Desabilitado"
}

output "external_secrets_namespace" {
  description = "Namespace do External Secrets Operator"
  value       = var.enable_external_secrets ? "external-secrets-system" : null
}

# -----------------------------------------------------------------------------
# IRSA IAM Roles
# -----------------------------------------------------------------------------

output "app_secrets_access_role_arn_development" {
  description = "ARN da IAM Role para acesso aos Secrets Manager - Development"
  value       = aws_iam_role.app_secrets_access_development.arn
}

output "app_secrets_access_role_name_development" {
  description = "Nome da IAM Role para acesso aos Secrets Manager - Development"
  value       = aws_iam_role.app_secrets_access_development.name
}

output "app_secrets_access_role_arn_production" {
  description = "ARN da IAM Role para acesso aos Secrets Manager - Production"
  value       = aws_iam_role.app_secrets_access_production.arn
}

output "app_secrets_access_role_name_production" {
  description = "Nome da IAM Role para acesso aos Secrets Manager - Production"
  value       = aws_iam_role.app_secrets_access_production.name
}

# -----------------------------------------------------------------------------
# CloudWatch Dashboards
# -----------------------------------------------------------------------------

output "cloudwatch_dashboard_service_orders" {
  description = "URL do CloudWatch Dashboard para Service Orders"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.service_orders.dashboard_name}"
}

output "cloudwatch_dashboard_performance" {
  description = "URL do CloudWatch Dashboard para Application Performance"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.application_performance.dashboard_name}"
}

output "cloudwatch_dashboard_infrastructure" {
  description = "URL do CloudWatch Dashboard para Infrastructure"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.infrastructure.dashboard_name}"
}

output "cloudwatch_alarms_sns_topic" {
  description = "SNS Topic ARN para alertas CloudWatch"
  value       = aws_sns_topic.cloudwatch_alarms.arn
}

# -----------------------------------------------------------------------------
# Summary Output
# -----------------------------------------------------------------------------

output "summary" {
  description = "Resumo dos addons instalados - Fase 2"
  value       = <<-EOT
    ================================================================================
    FIAP Tech Challenge - Kubernetes Addons (Phase 2)
    ================================================================================

    Cluster EKS: ${local.cluster_name}

    Namespaces Criados:
      - ${kubernetes_namespace.development.metadata[0].name} (Development)
      - ${kubernetes_namespace.production.metadata[0].name} (Production)

    Addons Instalados:
      - AWS Load Balancer Controller: ${var.enable_aws_lb_controller ? "Instalado" : "Desabilitado"}
      - External Secrets Operator: ${var.enable_external_secrets ? "Instalado (v${var.external_secrets_version})" : "Desabilitado"}
      - Metrics Server: ${var.enable_metrics_server ? "Instalado" : "Desabilitado"}

    IRSA Roles (IAM Roles for Service Accounts):
      - Development: ${aws_iam_role.app_secrets_access_development.name}
      - Production: ${aws_iam_role.app_secrets_access_production.name}

    Observabilidade:
      - CloudWatch Container Insights (nativo AWS)
      - CloudWatch Logs para application logs (JSON via Pino)
      - 3 Dashboards CloudWatch criados:
        * Service Orders (volume, tempo médio por status)
        * Application Performance (latência, erros)
        * Infrastructure (CPU, memória, pods, nodes)
      - 6 CloudWatch Alarms configurados:
        * High Error Rate (5xx > 10)
        * High Latency (P95 > 2s)
        * High CPU (> 80%)
        * High Memory (> 85%)
        * Pod Crashes
        * Service Order Failures

    Dashboards URLs:
      terraform output cloudwatch_dashboard_service_orders
      terraform output cloudwatch_dashboard_performance
      terraform output cloudwatch_dashboard_infrastructure

    Proximo passo:
      Deploy database-managed-infra e k8s-main-service
    ================================================================================
  EOT
}
