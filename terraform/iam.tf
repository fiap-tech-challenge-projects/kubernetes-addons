# =============================================================================
# IAM - Application IRSA Roles
# =============================================================================
# IAM Roles for Service Accounts (IRSA) for application pods
# Allows pods to access AWS services (Secrets Manager) without static credentials
# =============================================================================

# -----------------------------------------------------------------------------
# Data: OIDC Provider from kubernetes-core-infra
# -----------------------------------------------------------------------------

data "aws_eks_cluster" "main" {
  name = local.cluster_name
}

data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# -----------------------------------------------------------------------------
# IAM Role for Application Pods - Development
# -----------------------------------------------------------------------------
# Allows pods in ftc-app-development namespace to access Secrets Manager

resource "aws_iam_role" "app_secrets_access_development" {
  name = "${var.project_name}-secrets-access-development"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:${var.app_namespace}-development:fiap-tech-challenge-api"
            "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  # AWS Academy: Cannot tag IAM roles
  tags = {}
}

# Policy allowing read access to Secrets Manager
resource "aws_iam_policy" "secrets_manager_read_development" {
  name        = "${var.project_name}-secrets-manager-read-development"
  description = "Allow application pods to read secrets from AWS Secrets Manager - Development"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/development/*"
        ]
      }
    ]
  })

  # AWS Academy: Cannot tag IAM policies
  tags = {}
}

resource "aws_iam_role_policy_attachment" "app_secrets_access_development" {
  role       = aws_iam_role.app_secrets_access_development.name
  policy_arn = aws_iam_policy.secrets_manager_read_development.arn
}

# -----------------------------------------------------------------------------
# IAM Role for Application Pods - Production
# -----------------------------------------------------------------------------
# Allows pods in ftc-app-production namespace to access Secrets Manager

resource "aws_iam_role" "app_secrets_access_production" {
  name = "${var.project_name}-secrets-access-production"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:${var.app_namespace}-production:fiap-tech-challenge-api"
            "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  # AWS Academy: Cannot tag IAM roles
  tags = {}
}

# Policy allowing read access to Secrets Manager
resource "aws_iam_policy" "secrets_manager_read_production" {
  name        = "${var.project_name}-secrets-manager-read-production"
  description = "Allow application pods to read secrets from AWS Secrets Manager - Production"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/production/*"
        ]
      }
    ]
  })

  # AWS Academy: Cannot tag IAM policies
  tags = {}
}

resource "aws_iam_role_policy_attachment" "app_secrets_access_production" {
  role       = aws_iam_role.app_secrets_access_production.name
  policy_arn = aws_iam_policy.secrets_manager_read_production.arn
}
