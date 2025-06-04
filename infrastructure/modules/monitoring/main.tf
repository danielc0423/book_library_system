# ====================================
# Monitoring Module - Main Configuration
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# Log Analytics Workspace
# ====================================

resource "oci_log_analytics_namespace" "library_analytics" {
  count = var.enable_log_analytics ? 1 : 0
  
  namespace           = var.log_analytics_namespace
  compartment_id     = var.compartment_ocid
  is_onboarded       = true
}

# ====================================
# OCI Logging Service Configuration
# ====================================

# Log Group for Application Logs
resource "oci_logging_log_group" "app_logs" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-${var.environment}-app-logs"
  description    = "Log group for application logs"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-app-logs"
    Type = "logging"
  })
}

# Log Group for Infrastructure Logs
resource "oci_logging_log_group" "infrastructure_logs" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-${var.environment}-infra-logs"
  description    = "Log group for infrastructure logs"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-infra-logs"
    Type = "logging"
  })
}

# Log Group for Security Logs
resource "oci_logging_log_group" "security_logs" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-${var.environment}-security-logs"
  description    = "Log group for security and audit logs"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-security-logs"
    Type = "logging"
  })
}

# ====================================
# Custom Application Logs
# ====================================

# Django Application Logs
resource "oci_logging_log" "django_app_log" {
  display_name       = "${var.project_name}-${var.environment}-django-app"
  log_group_id      = oci_logging_log_group.app_logs.id
  log_type          = "CUSTOM"
  
  configuration {
    source {
      category    = "application"
      resource    = var.instance_pool_id
      service     = "compute"
      source_type = "OCISERVICE"
    }
    
    compartment_id = var.compartment_ocid
  }

  is_enabled         = true
  retention_duration = var.log_retention_days

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-django-app"
    Type = "application_log"
  })
}

# API Request Logs
resource "oci_logging_log" "api_request_log" {
  display_name       = "${var.project_name}-${var.environment}-api-requests"
  log_group_id      = oci_logging_log_group.app_logs.id
  log_type          = "CUSTOM"
  
  configuration {
    source {
      category    = "application"
      resource    = var.load_balancer_id
      service     = "loadbalancer"
      source_type = "OCISERVICE"
    }
    
    compartment_id = var.compartment_ocid
  }

  is_enabled         = true
  retention_duration = var.log_retention_days

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-api-requests"
    Type = "api_log"
  })
}

# Database Connection Logs
resource "oci_logging_log" "database_log" {
  count = var.database_id != "" ? 1 : 0
  
  display_name       = "${var.project_name}-${var.environment}-database"
  log_group_id      = oci_logging_log_group.app_logs.id
  log_type          = "CUSTOM"
  
  configuration {
    source {
      category    = "database"
      resource    = var.database_id
      service     = "database"
      source_type = "OCISERVICE"
    }
    
    compartment_id = var.compartment_ocid
  }

  is_enabled         = true
  retention_duration = var.log_retention_days

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-database"
    Type = "database_log"
  })
}

# ====================================
# Infrastructure Logs
# ====================================

# VCN Flow Logs
resource "oci_logging_log" "vcn_flow_log" {
  display_name       = "${var.project_name}-${var.environment}-vcn-flow"
  log_group_id      = oci_logging_log_group.infrastructure_logs.id
  log_type          = "SERVICE"
  
  configuration {
    source {
      category    = "all"
      resource    = var.vcn_id
      service     = "flowlogs"
      source_type = "OCISERVICE"
    }
    
    compartment_id = var.compartment_ocid
  }

  is_enabled         = true
  retention_duration = var.log_retention_days

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-vcn-flow"
    Type = "network_log"
  })
}

# Load Balancer Access Logs
resource "oci_logging_log" "lb_access_log" {
  count = var.load_balancer_id != "" ? 1 : 0
  
  display_name       = "${var.project_name}-${var.environment}-lb-access"
  log_group_id      = oci_logging_log_group.infrastructure_logs.id
  log_type          = "SERVICE"
  
  configuration {
    source {
      category    = "access"
      resource    = var.load_balancer_id
      service     = "loadbalancer"
      source_type = "OCISERVICE"
    }
    
    compartment_id = var.compartment_ocid
  }

  is_enabled         = true
  retention_duration = var.log_retention_days

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-lb-access"
    Type = "access_log"
  })
}

# Load Balancer Error Logs
resource "oci_logging_log" "lb_error_log" {
  count = var.load_balancer_id != "" ? 1 : 0
  
  display_name       = "${var.project_name}-${var.environment}-lb-error"
  log_group_id      = oci_logging_log_group.infrastructure_logs.id
  log_type          = "SERVICE"
  
  configuration {
    source {
      category    = "error"
      resource    = var.load_balancer_id
      service     = "loadbalancer"
      source_type = "OCISERVICE"
    }
    
    compartment_id = var.compartment_ocid
  }

  is_enabled         = true
  retention_duration = var.log_retention_days

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-lb-error"
    Type = "error_log"
  })
}

# ====================================
# Security and Audit Logs
# ====================================

# Audit Logs
resource "oci_logging_log" "audit_log" {
  display_name       = "${var.project_name}-${var.environment}-audit"
  log_group_id      = oci_logging_log_group.security_logs.id
  log_type          = "SERVICE"
  
  configuration {
    source {
      category    = "all"
      resource    = var.compartment_ocid
      service     = "audit"
      source_type = "OCISERVICE"
    }
    
    compartment_id = var.compartment_ocid
  }

  is_enabled         = true
  retention_duration = var.audit_log_retention_days

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-audit"
    Type = "audit_log"
  })
}

# WAF Logs (if WAF is enabled)
resource "oci_logging_log" "waf_log" {
  count = var.waf_policy_id != "" ? 1 : 0
  
  display_name       = "${var.project_name}-${var.environment}-waf"
  log_group_id      = oci_logging_log_group.security_logs.id
  log_type          = "SERVICE"
  
  configuration {
    source {
      category    = "all"
      resource    = var.waf_policy_id
      service     = "waf"
      source_type = "OCISERVICE"
    }
    
    compartment_id = var.compartment_ocid
  }

  is_enabled         = true
  retention_duration = var.log_retention_days

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-waf"
    Type = "security_log"
  })
}

# ====================================
# OCI Monitoring Alarms
# ====================================

# High CPU Utilization Alarm
resource "oci_monitoring_alarm" "high_cpu_alarm" {
  compartment_id        = var.compartment_ocid
  display_name         = "${var.project_name}-${var.environment}-high-cpu"
  destinations         = [var.notification_topic_id]
  is_enabled          = var.enable_monitoring_alarms
  metric_compartment_id = var.compartment_ocid
  severity            = "CRITICAL"
  
  query = "CpuUtilization[1m].mean() > ${var.cpu_alarm_threshold}"
  
  suppression {
    time_suppress_from  = "2024-01-01T00:00:00Z"
    time_suppress_until = "2024-01-01T23:59:59Z"
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-high-cpu"
    Type = "alarm"
  })
}

# High Memory Utilization Alarm
resource "oci_monitoring_alarm" "high_memory_alarm" {
  compartment_id        = var.compartment_ocid
  display_name         = "${var.project_name}-${var.environment}-high-memory"
  destinations         = [var.notification_topic_id]
  is_enabled          = var.enable_monitoring_alarms
  metric_compartment_id = var.compartment_ocid
  severity            = "WARNING"
  
  query = "MemoryUtilization[1m].mean() > ${var.memory_alarm_threshold}"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-high-memory"
    Type = "alarm"
  })
}

# Instance Down Alarm
resource "oci_monitoring_alarm" "instance_down_alarm" {
  compartment_id        = var.compartment_ocid
  display_name         = "${var.project_name}-${var.environment}-instance-down"
  destinations         = [var.notification_topic_id]
  is_enabled          = var.enable_monitoring_alarms
  metric_compartment_id = var.compartment_ocid
  severity            = "CRITICAL"
  
  query = "InstanceHealthStatus[1m].mean() < 1"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-instance-down"
    Type = "alarm"
  })
}

# Load Balancer Unhealthy Backends Alarm
resource "oci_monitoring_alarm" "lb_unhealthy_backends_alarm" {
  count = var.load_balancer_id != "" ? 1 : 0
  
  compartment_id        = var.compartment_ocid
  display_name         = "${var.project_name}-${var.environment}-lb-unhealthy-backends"
  destinations         = [var.notification_topic_id]
  is_enabled          = var.enable_monitoring_alarms
  metric_compartment_id = var.compartment_ocid
  severity            = "WARNING"
  
  query = "UnHealthyBackendCount[1m].mean() > 0"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-lb-unhealthy-backends"
    Type = "alarm"
  })
}

# High Response Time Alarm
resource "oci_monitoring_alarm" "high_response_time_alarm" {
  count = var.load_balancer_id != "" ? 1 : 0
  
  compartment_id        = var.compartment_ocid
  display_name         = "${var.project_name}-${var.environment}-high-response-time"
  destinations         = [var.notification_topic_id]
  is_enabled          = var.enable_monitoring_alarms
  metric_compartment_id = var.compartment_ocid
  severity            = "WARNING"
  
  query = "ResponseTime[1m].mean() > ${var.response_time_threshold_ms}"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-high-response-time"
    Type = "alarm"
  })
}

# Database Connection Alarm
resource "oci_monitoring_alarm" "database_connection_alarm" {
  count = var.database_id != "" ? 1 : 0
  
  compartment_id        = var.compartment_ocid
  display_name         = "${var.project_name}-${var.environment}-db-connection"
  destinations         = [var.notification_topic_id]
  is_enabled          = var.enable_monitoring_alarms
  metric_compartment_id = var.compartment_ocid
  severity            = "CRITICAL"
  
  query = "DatabaseConnections[1m].mean() > ${var.db_connection_threshold}"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-connection"
    Type = "alarm"
  })
}

# ====================================
# Custom Metrics for Application
# ====================================

# Application Health Check Metric
resource "oci_monitoring_alarm" "app_health_check_alarm" {
  compartment_id        = var.compartment_ocid
  display_name         = "${var.project_name}-${var.environment}-app-health"
  destinations         = [var.notification_topic_id]
  is_enabled          = var.enable_monitoring_alarms
  metric_compartment_id = var.compartment_ocid
  severity            = "CRITICAL"
  
  query = "ApplicationHealthCheck[1m].mean() < 1"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-app-health"
    Type = "alarm"
  })
}

# API Error Rate Alarm
resource "oci_monitoring_alarm" "api_error_rate_alarm" {
  compartment_id        = var.compartment_ocid
  display_name         = "${var.project_name}-${var.environment}-api-error-rate"
  destinations         = [var.notification_topic_id]
  is_enabled          = var.enable_monitoring_alarms
  metric_compartment_id = var.compartment_ocid
  severity            = "WARNING"
  
  query = "APIErrorRate[5m].mean() > ${var.api_error_rate_threshold}"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-api-error-rate"
    Type = "alarm"
  })
}

# ====================================
# Log Analytics Saved Searches
# ====================================

resource "oci_log_analytics_log_analytics_entity" "app_entity" {
  count = var.enable_log_analytics ? 1 : 0
  
  compartment_id = var.compartment_ocid
  namespace      = oci_log_analytics_namespace.library_analytics[0].namespace
  name          = "${var.project_name}-${var.environment}-app-entity"
  entity_type_name = "Host (Linux)"
  
  properties = {
    "displayName" = "${var.project_name} Application Entity"
    "description" = "Log Analytics entity for library application"
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-app-entity"
    Type = "log_analytics"
  })
}

# ====================================
# Dashboard Configuration
# ====================================

# Application Performance Dashboard
resource "oci_management_dashboard_management_dashboard" "app_dashboard" {
  count = var.create_dashboards ? 1 : 0
  
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-${var.environment}-app-dashboard"
  description    = "Application performance and monitoring dashboard"
  
  config = jsonencode({
    version = "1.0"
    widgets = [
      {
        id = "cpu_utilization"
        title = "CPU Utilization"
        type = "line_chart"
        query = "CpuUtilization[1m].mean()"
        timeRange = "last_hour"
      },
      {
        id = "memory_utilization"
        title = "Memory Utilization"
        type = "line_chart"
        query = "MemoryUtilization[1m].mean()"
        timeRange = "last_hour"
      },
      {
        id = "response_time"
        title = "Response Time"
        type = "line_chart"
        query = "ResponseTime[1m].mean()"
        timeRange = "last_hour"
      },
      {
        id = "error_rate"
        title = "Error Rate"
        type = "line_chart"
        query = "APIErrorRate[5m].mean()"
        timeRange = "last_hour"
      }
    ]
  })

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-app-dashboard"
    Type = "dashboard"
  })
}

# Infrastructure Dashboard
resource "oci_management_dashboard_management_dashboard" "infra_dashboard" {
  count = var.create_dashboards ? 1 : 0
  
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-${var.environment}-infra-dashboard"
  description    = "Infrastructure monitoring dashboard"
  
  config = jsonencode({
    version = "1.0"
    widgets = [
      {
        id = "instance_health"
        title = "Instance Health"
        type = "status_chart"
        query = "InstanceHealthStatus[1m].mean()"
        timeRange = "last_hour"
      },
      {
        id = "network_throughput"
        title = "Network Throughput"
        type = "line_chart"
        query = "NetworkThroughput[1m].mean()"
        timeRange = "last_hour"
      },
      {
        id = "disk_utilization"
        title = "Disk Utilization"
        type = "gauge_chart"
        query = "DiskUtilization[1m].mean()"
        timeRange = "current"
      },
      {
        id = "load_balancer_status"
        title = "Load Balancer Status"
        type = "status_chart"
        query = "LoadBalancerHealthStatus[1m].mean()"
        timeRange = "last_hour"
      }
    ]
  })

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-infra-dashboard"
    Type = "dashboard"
  })
}

# ====================================
# Health Checks
# ====================================

# Application Health Check
resource "oci_health_checks_http_monitor" "app_health_check" {
  compartment_id      = var.compartment_ocid
  display_name        = "${var.project_name}-${var.environment}-app-health-check"
  interval_in_seconds = var.health_check_interval_seconds
  protocol           = var.health_check_protocol
  targets            = [var.load_balancer_ip]
  path              = var.health_check_path
  port              = var.health_check_port
  timeout_in_seconds = var.health_check_timeout_seconds
  
  is_enabled = true

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-app-health-check"
    Type = "health_check"
  })
}

# API Endpoint Health Check
resource "oci_health_checks_http_monitor" "api_health_check" {
  compartment_id      = var.compartment_ocid
  display_name        = "${var.project_name}-${var.environment}-api-health-check"
  interval_in_seconds = var.health_check_interval_seconds
  protocol           = var.health_check_protocol
  targets            = [var.load_balancer_ip]
  path              = "/api/v1/health/"
  port              = var.health_check_port
  timeout_in_seconds = var.health_check_timeout_seconds
  
  is_enabled = true

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-api-health-check"
    Type = "health_check"
  })
}

# ====================================
# Performance Monitoring
# ====================================

# APM Domain for Application Performance Monitoring
resource "oci_apm_apm_domain" "app_apm" {
  count = var.enable_apm ? 1 : 0
  
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-${var.environment}-apm"
  description    = "Application Performance Monitoring domain"
  is_free_tier   = var.apm_free_tier

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-apm"
    Type = "apm"
  })
}

# ====================================
# Event Rules and Notifications
# ====================================

# Instance State Change Event Rule
resource "oci_events_rule" "instance_state_change" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-${var.environment}-instance-state-change"
  description    = "Rule for instance state change events"
  is_enabled     = true
  
  condition = jsonencode({
    eventType = ["com.oraclecloud.computeapi.terminateinstance.end", "com.oraclecloud.computeapi.launchinstance.end"]
    data = {
      compartmentId = var.compartment_ocid
    }
  })
  
  actions {
    actions {
      action_type = "ONS"
      is_enabled  = true
      topic_id    = var.notification_topic_id
    }
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-instance-state-change"
    Type = "event_rule"
  })
}

# Database State Change Event Rule
resource "oci_events_rule" "database_state_change" {
  count = var.database_id != "" ? 1 : 0
  
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-${var.environment}-database-state-change"
  description    = "Rule for database state change events"
  is_enabled     = true
  
  condition = jsonencode({
    eventType = ["com.oraclecloud.databaseservice.autonomous.database.instance.state.change"]
    data = {
      compartmentId = var.compartment_ocid
    }
  })
  
  actions {
    actions {
      action_type = "ONS"
      is_enabled  = true
      topic_id    = var.notification_topic_id
    }
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-database-state-change"
    Type = "event_rule"
  })
}

# ====================================
# Log Shipping and Archival
# ====================================

# Log Bucket for Long-term Storage
resource "oci_objectstorage_bucket" "log_archive_bucket" {
  count = var.enable_log_archival ? 1 : 0
  
  compartment_id = var.compartment_ocid
  namespace      = var.object_storage_namespace
  name          = "${var.project_name}-${var.environment}-log-archive"
  access_type   = "NoPublicAccess"
  
  versioning    = "Enabled"
  
  retention_rules {
    display_name = "log-retention-rule"
    duration {
      time_amount = var.log_archive_retention_days
      time_unit   = "DAYS"
    }
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-log-archive"
    Type = "log_storage"
  })
}
