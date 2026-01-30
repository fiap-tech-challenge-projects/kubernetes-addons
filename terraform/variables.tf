# =============================================================================
# Variaveis de Entrada - Kubernetes Addons (Phase 2)
# =============================================================================

# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "Regiao AWS para deploy dos recursos"
  type        = string
  default     = "us-east-1"
}

# -----------------------------------------------------------------------------
# Project Configuration
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Nome do projeto (usado para nomear recursos)"
  type        = string
  default     = "fiap-tech-challenge"

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]*[a-z0-9])?$", var.project_name))
    error_message = "Project name deve ser lowercase com letras, numeros e hifens."
  }
}

variable "environment" {
  description = "Ambiente de deploy (development, staging, production)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment deve ser: development, staging ou production."
  }
}

variable "common_tags" {
  description = "Tags comuns aplicadas a todos os recursos"
  type        = map(string)
  default = {
    Project   = "fiap-tech-challenge"
    Phase     = "3"
    ManagedBy = "terraform"
    Team      = "fiap-pos-grad"
  }
}

# -----------------------------------------------------------------------------
# Application Namespace
# -----------------------------------------------------------------------------

variable "app_namespace" {
  description = "Namespace para a aplicacao principal"
  type        = string
  default     = "ftc-app"

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]*[a-z0-9])?$", var.app_namespace))
    error_message = "Namespace deve ser lowercase com letras, numeros e hifens."
  }
}

# -----------------------------------------------------------------------------
# SigNoz Configuration
# -----------------------------------------------------------------------------

variable "enable_signoz" {
  description = "Habilitar instalacao do SigNoz para observabilidade"
  type        = bool
  default     = false # Disabled by default for faster deployment
}

variable "signoz_namespace" {
  description = "Namespace para o SigNoz"
  type        = string
  default     = "signoz"
}

variable "signoz_chart_version" {
  description = "Versao do Helm chart do SigNoz"
  type        = string
  default     = "0.32.0"
}

variable "signoz_storage_size" {
  description = "Tamanho do storage para ClickHouse do SigNoz"
  type        = string
  default     = "20Gi"
}

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller
# -----------------------------------------------------------------------------

variable "enable_aws_lb_controller" {
  description = "Habilitar AWS Load Balancer Controller"
  type        = bool
  default     = false # Disabled for Free Tier (too resource-intensive for t3.micro)
}

variable "aws_lb_controller_version" {
  description = "Versao do AWS Load Balancer Controller"
  type        = string
  default     = "1.6.2"
}
