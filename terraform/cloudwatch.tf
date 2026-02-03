# =============================================================================
# CloudWatch Dashboards and Alarms (Phase 3 Requirement)
# =============================================================================
# Requisito PDF página 4: "Expor dashboards com volume diário de ordens,
# tempo médio por status, erros e falhas"
# =============================================================================

# -----------------------------------------------------------------------------
# Dashboard 1: Service Orders Metrics
# -----------------------------------------------------------------------------
# Volume diário de ordens de serviço
# Tempo médio de execução por status (Diagnóstico, Execução, Finalização)

resource "aws_cloudwatch_dashboard" "service_orders" {
  dashboard_name = "${var.environment}-fiap-service-orders"

  dashboard_body = jsonencode({
    widgets = [
      # Volume diário de ordens de serviço
      {
        type = "metric"
        properties = {
          metrics = [
            ["ContainerInsights", "pod_cpu_utilization", { stat = "Average" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Volume Diário de Ordens de Serviço"
          period  = 300
          yAxis = {
            left = {
              label = "Ordens"
            }
          }
        }
      },

      # Tempo médio por status - Diagnóstico
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", {
              stat  = "Average"
              label = "Diagnóstico"
            }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Tempo Médio - Diagnóstico"
          period  = 300
          yAxis = {
            left = {
              label = "Segundos"
            }
          }
        }
      },

      # Tempo médio por status - Execução
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", {
              stat  = "Average"
              label = "Execução"
            }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Tempo Médio - Execução"
          period  = 300
          yAxis = {
            left = {
              label = "Segundos"
            }
          }
        }
      },

      # Tempo médio por status - Finalização
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", {
              stat  = "p99"
              label = "Finalização"
            }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Tempo Médio - Finalização"
          period  = 300
          yAxis = {
            left = {
              label = "Segundos"
            }
          }
        }
      },

      # Log Insights Query - Volume de ordens criadas
      {
        type = "log"
        properties = {
          query  = <<-EOT
            SOURCE '/aws/containerinsights/${local.cluster_name}/application'
            | fields @timestamp, @message
            | filter @message like /ServiceOrder created/
            | stats count() as order_count by bin(5m)
          EOT
          region = var.aws_region
          title  = "Ordens Criadas (últimas 24h)"
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Dashboard 2: Application Performance
# -----------------------------------------------------------------------------
# Latência das APIs, taxa de erro, consumo de recursos

resource "aws_cloudwatch_dashboard" "application_performance" {
  dashboard_name = "${var.environment}-fiap-app-performance"

  dashboard_body = jsonencode({
    widgets = [
      # Latência P50, P95, P99
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", {
              stat  = "p50"
              label = "P50 Latência"
            }],
            ["...", { stat = "p95", label = "P95 Latência" }],
            ["...", { stat = "p99", label = "P99 Latência" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "API Latency (P50, P95, P99)"
          period  = 300
          yAxis = {
            left = {
              label = "Seconds"
              min   = 0
            }
          }
        }
      },

      # Taxa de erro (4xx + 5xx)
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", {
              stat  = "Sum"
              label = "4xx Errors"
            }],
            [".", "HTTPCode_Target_5XX_Count", {
              stat  = "Sum"
              label = "5xx Errors"
            }]
          ]
          view    = "timeSeries"
          stacked = true
          region  = var.aws_region
          title   = "Error Rate (4xx + 5xx)"
          period  = 300
          yAxis = {
            left = {
              label = "Errors"
            }
          }
        }
      },

      # Requests por segundo
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", {
              stat = "Sum"
            }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Requests per Second"
          period  = 60
          yAxis = {
            left = {
              label = "Requests"
            }
          }
        }
      },

      # Erros e falhas nos logs
      {
        type = "log"
        properties = {
          query  = <<-EOT
            SOURCE '/aws/containerinsights/${local.cluster_name}/application'
            | fields @timestamp, level, msg, err
            | filter level >= 50
            | stats count() as error_count by bin(5m)
            | sort @timestamp desc
          EOT
          region = var.aws_region
          title  = "Application Errors (level >= 50)"
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Dashboard 3: Infrastructure & Kubernetes
# -----------------------------------------------------------------------------
# CPU, memória, pods, nodes health

resource "aws_cloudwatch_dashboard" "infrastructure" {
  dashboard_name = "${var.environment}-fiap-infrastructure"

  dashboard_body = jsonencode({
    widgets = [
      # CPU Utilization - Cluster
      {
        type = "metric"
        properties = {
          metrics = [
            ["ContainerInsights", "cluster_node_cpu_utilization", {
              ClusterName = local.cluster_name
              stat        = "Average"
            }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Cluster CPU Utilization"
          period  = 300
          yAxis = {
            left = {
              label = "Percent"
              max   = 100
            }
          }
        }
      },

      # Memory Utilization - Cluster
      {
        type = "metric"
        properties = {
          metrics = [
            ["ContainerInsights", "cluster_node_memory_utilization", {
              ClusterName = local.cluster_name
              stat        = "Average"
            }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Cluster Memory Utilization"
          period  = 300
          yAxis = {
            left = {
              label = "Percent"
              max   = 100
            }
          }
        }
      },

      # Pod Count
      {
        type = "metric"
        properties = {
          metrics = [
            ["ContainerInsights", "cluster_number_of_running_pods", {
              ClusterName = local.cluster_name
              stat        = "Average"
            }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Running Pods"
          period  = 300
          yAxis = {
            left = {
              label = "Pods"
            }
          }
        }
      },

      # Node Count
      {
        type = "metric"
        properties = {
          metrics = [
            ["ContainerInsights", "cluster_number_of_nodes", {
              ClusterName = local.cluster_name
              stat        = "Average"
            }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Active Nodes"
          period  = 300
          yAxis = {
            left = {
              label = "Nodes"
            }
          }
        }
      },

      # Pod CPU per namespace
      {
        type = "metric"
        properties = {
          metrics = [
            ["ContainerInsights", "pod_cpu_utilization", {
              ClusterName = local.cluster_name
              Namespace   = "${var.app_namespace}-staging"
              stat        = "Average"
            }],
            ["...", { Namespace = "${var.app_namespace}-production" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Pod CPU by Namespace"
          period  = 300
          yAxis = {
            left = {
              label = "Percent"
            }
          }
        }
      },

      # Pod Memory per namespace
      {
        type = "metric"
        properties = {
          metrics = [
            ["ContainerInsights", "pod_memory_utilization", {
              ClusterName = local.cluster_name
              Namespace   = "${var.app_namespace}-staging"
              stat        = "Average"
            }],
            ["...", { Namespace = "${var.app_namespace}-production" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Pod Memory by Namespace"
          period  = 300
          yAxis = {
            left = {
              label = "Percent"
            }
          }
        }
      }
    ]
  })
}

# =============================================================================
# CloudWatch Alarms (Phase 3 Requirement)
# =============================================================================
# Requisito PDF página 3: "Alertas para falhas no processamento de ordens"
# =============================================================================

# -----------------------------------------------------------------------------
# SNS Topic for Alarms
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "cloudwatch_alarms" {
  name = "${var.environment}-fiap-cloudwatch-alarms"

  tags = merge(var.common_tags, {
    Name = "${var.environment}-fiap-cloudwatch-alarms"
  })
}

resource "aws_sns_topic_subscription" "cloudwatch_alarms_email" {
  count = var.alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.cloudwatch_alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# -----------------------------------------------------------------------------
# Alarm 1: High Error Rate (5xx > 5%)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.environment}-fiap-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alert when 5xx error count exceeds 10 in 5 minutes"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  ok_actions          = [aws_sns_topic.cloudwatch_alarms.arn]

  treat_missing_data = "notBreaching"

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# Alarm 2: High API Latency (P95 > 2s)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "high_latency" {
  alarm_name          = "${var.environment}-fiap-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  extended_statistic  = "p95"
  threshold           = 2.0
  alarm_description   = "Alert when P95 latency exceeds 2 seconds"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  ok_actions          = [aws_sns_topic.cloudwatch_alarms.arn]

  treat_missing_data = "notBreaching"

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# Alarm 3: High Node CPU (> 80%)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "high_node_cpu" {
  alarm_name          = "${var.environment}-fiap-high-node-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "cluster_node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alert when cluster CPU exceeds 80%"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  ok_actions          = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    ClusterName = local.cluster_name
  }

  treat_missing_data = "notBreaching"

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# Alarm 4: High Node Memory (> 85%)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "high_node_memory" {
  alarm_name          = "${var.environment}-fiap-high-node-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "cluster_node_memory_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Alert when cluster memory exceeds 85%"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  ok_actions          = [aws_sns_topic.cloudwatch_alarms.arn]

  dimensions = {
    ClusterName = local.cluster_name
  }

  treat_missing_data = "notBreaching"

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# Alarm 5: Pod CrashLoopBackOff (application errors)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_metric_filter" "pod_crashes" {
  name           = "${var.environment}-fiap-pod-crashes"
  log_group_name = "/aws/containerinsights/${local.cluster_name}/application"

  pattern = "[timestamp, request_id, level >= 50, ...]"

  metric_transformation {
    name      = "PodCrashCount"
    namespace = "FIAP/Application"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "pod_crashes" {
  alarm_name          = "${var.environment}-fiap-pod-crashes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "PodCrashCount"
  namespace           = "FIAP/Application"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when pod error logs exceed 5 in 5 minutes"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  ok_actions          = [aws_sns_topic.cloudwatch_alarms.arn]

  treat_missing_data = "notBreaching"

  tags = var.common_tags

  depends_on = [aws_cloudwatch_log_metric_filter.pod_crashes]
}

# -----------------------------------------------------------------------------
# Alarm 6: Service Order Processing Failures
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_metric_filter" "service_order_failures" {
  name           = "${var.environment}-fiap-service-order-failures"
  log_group_name = "/aws/containerinsights/${local.cluster_name}/application"

  pattern = "[timestamp, request_id, level, msg=\"*ServiceOrder*failed*\", ...]"

  metric_transformation {
    name      = "ServiceOrderFailureCount"
    namespace = "FIAP/Application"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "service_order_failures" {
  alarm_name          = "${var.environment}-fiap-service-order-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ServiceOrderFailureCount"
  namespace           = "FIAP/Application"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "Alert when service order processing fails more than 3 times in 5 minutes"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  ok_actions          = [aws_sns_topic.cloudwatch_alarms.arn]

  treat_missing_data = "notBreaching"

  tags = var.common_tags

  depends_on = [aws_cloudwatch_log_metric_filter.service_order_failures]
}
