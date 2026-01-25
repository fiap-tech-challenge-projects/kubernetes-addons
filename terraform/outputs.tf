# =============================================================================
# Outputs - Kubernetes Addons (Phase 2)
# =============================================================================

# -----------------------------------------------------------------------------
# Namespace Outputs
# -----------------------------------------------------------------------------

output "staging_namespace" {
  description = "Namespace da aplicacao - Staging"
  value       = kubernetes_namespace.staging.metadata[0].name
}

output "production_namespace" {
  description = "Namespace da aplicacao - Production"
  value       = kubernetes_namespace.production.metadata[0].name
}

output "signoz_namespace" {
  description = "Namespace do SigNoz"
  value       = var.enable_signoz ? kubernetes_namespace.signoz[0].metadata[0].name : null
}

# -----------------------------------------------------------------------------
# SigNoz Access
# -----------------------------------------------------------------------------

output "signoz_frontend_service" {
  description = "Como acessar o SigNoz Frontend"
  value       = var.enable_signoz ? "kubectl port-forward -n ${var.signoz_namespace} svc/signoz-frontend 3301:3301" : null
}

output "signoz_otel_endpoint" {
  description = "Endpoint do OpenTelemetry Collector"
  value       = var.enable_signoz ? "signoz-otel-collector.${var.signoz_namespace}.svc.cluster.local:4317" : null
}

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller
# -----------------------------------------------------------------------------

output "aws_lb_controller_status" {
  description = "Status do AWS Load Balancer Controller"
  value       = var.enable_aws_lb_controller ? "Instalado" : "Desabilitado"
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
      - ${kubernetes_namespace.staging.metadata[0].name} (Staging)
      - ${kubernetes_namespace.production.metadata[0].name} (Production)
      ${var.enable_signoz ? "- ${var.signoz_namespace} (Observability)" : ""}

    Addons Instalados:
      - AWS Load Balancer Controller: ${var.enable_aws_lb_controller ? "Instalado" : "Desabilitado"}
      - Metrics Server: Instalado
      - SigNoz: ${var.enable_signoz ? "Instalado" : "Desabilitado"}

    ${var.enable_signoz ? "Acessar SigNoz:\n      kubectl port-forward -n ${var.signoz_namespace} svc/signoz-frontend 3301:3301\n      Abra: http://localhost:3301" : ""}

    Proximo passo:
      Deploy database-managed-infra e k8s-main-service
    ================================================================================
  EOT
}
