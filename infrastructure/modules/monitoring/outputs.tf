# ====================================
# Monitoring Module Outputs
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# Log Groups Outputs
# ====================================

output "log_group_app_id" {
  description = "OCID of the application log group"
  value       = oci_logging_log_group.app_logs.id
}

output "log_group_infrastructure_id" {
  description = "OCID of the infrastructure log group"
  value       = oci_logging_log_group.infrastructure_logs.id
}

output "log_group_security_id" {
  description = "OCID of the security log group"
  value       = oci_logging_log_group.security_logs.id
}

output "log_groups" {
  description = "Map of all log group names to their OCIDs"
  value = {
    application = oci_logging_log_group.app_logs.id
    infrastructure = oci_logging_log_group.infrastructure_logs.id
    security = oci_logging_log_group.security_logs.id
  }
}

# ====================================
# Individual Log Outputs
# ====================================

output "django_app_log_id" {
  description = "OCID of the Django application log"
  value       = oci_logging_log.django_app_log.id
}

output "api_request_log_id" {
  description = "OCID of the API request log"
  value       = oci_logging_log.api_request_log.id
}

output "database_log_id" {
  description = "OCID of the database log"
  value       = var.database_id != "" ? oci_logging_log.database_log[0].id : null
}

output "vcn_flow_log_id" {
  description = "OCID of the VCN flow log"
  value       = oci_logging_log.vcn_flow_log.id
}

output "lb_access_log_id" {
  description = "OCID of the load balancer access log"
  value       = var.load_balancer_id != "" ? oci_logging_log.lb_access_log[0].id : null
}

output "lb_error_log_id" {
  description = "OCID of the load balancer error log"
  value       = var.load_balancer_id != "" ? oci_logging_log.lb_error_log[0].id : null
}

output "audit_log_id" {
  description = "OCID of the audit log"
  value       = oci_logging_log.audit_log.id
}

output "waf_log_id" {
  description = "OCID of the WAF log"
  value       = var.waf_policy_id != "" ? oci_logging_log.waf_log[0].id : null
}

# ====================================
# Monitoring Alarms Outputs
# ====================================

output "high_cpu_alarm_id" {
  description = "OCID of the high CPU utilization alarm"
  value       = oci_monitoring_alarm.high_cpu_alarm.id
}

output "high_memory_alarm_id" {
  description = "OCID of the high memory utilization alarm"
  value       = oci_monitoring_alarm.high_memory_alarm.id
}

output "instance_down_alarm_id" {
  description = "OCID of the instance down alarm"
  value       = oci_monitoring_alarm.instance_down_alarm.id
}

output "lb_unhealthy_backends_alarm_id" {
  description = "OCID of the load balancer unhealthy backends alarm"
  value       = var.load_balancer_id != "" ? oci_monitoring_alarm.lb_unhealthy_backends_alarm[0].id : null
}

output "high_response_time_alarm_id" {
  description = "OCID of the high response time alarm"
  value       = var.load_balancer_id != "" ? oci_monitoring_alarm.high_response_time_alarm[0].id : null
}

output "database_connection_alarm_id" {
  description = "OCID of the database connection alarm"
  value       = var.database_id != "" ? oci_monitoring_alarm.database_connection_alarm[0].id : null
}

output "app_health_check_alarm_id" {
  description = "OCID of the application health check alarm"
  value       = oci_monitoring_alarm.app_health_check_alarm.id
}

output "api_error_rate_alarm_id" {
  description = "OCID of the API error rate alarm"
  value       = oci_monitoring_alarm.api_error_rate_alarm.id
}

output "monitoring_alarms" {
  description = "Map of all monitoring alarm names to their OCIDs"
  value = {
    high_cpu = oci_monitoring_alarm.high_cpu_alarm.id
    high_memory = oci_monitoring_alarm.high_memory_alarm.id
    instance_down = oci_monitoring_alarm.instance_down_alarm.id
    lb_unhealthy_backends = var.load_balancer_id != "" ? oci_monitoring_alarm.lb_unhealthy_backends_alarm[0].id : null
    high_response_time = var.load_balancer_id != "" ? oci_monitoring_alarm.high_response_time_alarm[0].id : null
    database_connection = var.database_id != "" ? oci_monitoring_alarm.database_connection_alarm[0].id : null
    app_health_check = oci_monitoring_alarm.app_health_check_alarm.id
    api_error_rate = oci_monitoring_alarm.api_error_rate_alarm.id
  }
}

# ====================================
# Log Analytics Outputs
# ====================================

output "log_analytics_namespace" {
  description = "Log Analytics namespace"
  value       = var.enable_log_analytics ? oci_log_analytics_namespace.library_analytics[0].namespace : null
}

output "log_analytics_entity_id" {
  description = "OCID of the Log Analytics entity"
  value       = var.enable_log_analytics ? oci_log_analytics_log_analytics_entity.app_entity[0].id : null
}

# ====================================
# Dashboard Outputs
# ====================================

output "app_dashboard_id" {
  description = "OCID of the application dashboard"
  value       = var.create_dashboards ? oci_management_dashboard_management_dashboard.app_dashboard[0].id : null
}

output "infra_dashboard_id" {
  description = "OCID of the infrastructure dashboard"
  value       = var.create_dashboards ? oci_management_dashboard_management_dashboard.infra_dashboard[0].id : null
}

output "dashboards" {
  description = "Map of dashboard names to their OCIDs"
  value = var.create_dashboards ? {
    application = oci_management_dashboard_management_dashboard.app_dashboard[0].id
    infrastructure = oci_management_dashboard_management_dashboard.infra_dashboard[0].id
  } : {}
}

# ====================================
# Health Check Outputs
# ====================================

output "app_health_check_id" {
  description = "OCID of the application health check"
  value       = oci_health_checks_http_monitor.app_health_check.id
}

output "api_health_check_id" {
  description = "OCID of the API health check"
  value       = oci_health_checks_http_monitor.api_health_check.id
}

output "health_checks" {
  description = "Map of health check names to their OCIDs"
  value = {
    application = oci_health_checks_http_monitor.app_health_check.id
    api = oci_health_checks_http_monitor.api_health_check.id
  }
}

output "health_check_configuration" {
  description = "Health check configuration details"
  value = {
    interval_seconds = var.health_check_interval_seconds
    timeout_seconds = var.health_check_timeout_seconds
    protocol = var.health_check_protocol
    path = var.health_check_path
    port = var.health_check_port
  }
}

# ====================================
# APM Outputs
# ====================================

output "apm_domain_id" {
  description = "OCID of the APM domain"
  value       = var.enable_apm ? oci_apm_apm_domain.app_apm[0].id : null
}

output "apm_data_upload_endpoint" {
  description = "APM data upload endpoint"
  value       = var.enable_apm ? oci_apm_apm_domain.app_apm[0].data_upload_endpoint : null
}

# ====================================
# Event Rules Outputs
# ====================================

output "instance_state_change_rule_id" {
  description = "OCID of the instance state change event rule"
  value       = oci_events_rule.instance_state_change.id
}

output "database_state_change_rule_id" {
  description = "OCID of the database state change event rule"
  value       = var.database_id != "" ? oci_events_rule.database_state_change[0].id : null
}

output "event_rules" {
  description = "Map of event rule names to their OCIDs"
  value = {
    instance_state_change = oci_events_rule.instance_state_change.id
    database_state_change = var.database_id != "" ? oci_events_rule.database_state_change[0].id : null
  }
}

# ====================================
# Storage Outputs
# ====================================

output "log_archive_bucket_name" {
  description = "Name of the log archive bucket"
  value       = var.enable_log_archival ? oci_objectstorage_bucket.log_archive_bucket[0].name : null
}

output "log_archive_bucket_namespace" {
  description = "Namespace of the log archive bucket"
  value       = var.enable_log_archival ? oci_objectstorage_bucket.log_archive_bucket[0].namespace : null
}

# ====================================
# Configuration Summary Outputs
# ====================================

output "monitoring_configuration" {
  description = "Complete monitoring configuration summary"
  value = {
    # Log Configuration
    logging = {
      log_groups = {
        application = oci_logging_log_group.app_logs.id
        infrastructure = oci_logging_log_group.infrastructure_logs.id
        security = oci_logging_log_group.security_logs.id
      }
      retention_days = var.log_retention_days
      audit_retention_days = var.audit_log_retention_days
      archival_enabled = var.enable_log_archival
    }
    
    # Alarm Configuration
    alarms = {
      enabled = var.enable_monitoring_alarms
      cpu_threshold = var.cpu_alarm_threshold
      memory_threshold = var.memory_alarm_threshold
      response_time_threshold_ms = var.response_time_threshold_ms
      api_error_rate_threshold = var.api_error_rate_threshold
      db_connection_threshold = var.db_connection_threshold
    }
    
    # Health Check Configuration
    health_checks = {
      interval_seconds = var.health_check_interval_seconds
      timeout_seconds = var.health_check_timeout_seconds
      protocol = var.health_check_protocol
      enabled_checks = [
        "application",
        "api"
      ]
    }
    
    # Dashboard Configuration
    dashboards = {
      enabled = var.create_dashboards
      refresh_interval = var.dashboard_refresh_interval
      available_dashboards = var.create_dashboards ? [
        "application",
        "infrastructure"
      ] : []
    }
    
    # APM Configuration
    apm = {
      enabled = var.enable_apm
      free_tier = var.apm_free_tier
      domain_id = var.enable_apm ? oci_apm_apm_domain.app_apm[0].id : null
    }
    
    # Log Analytics Configuration
    log_analytics = {
      enabled = var.enable_log_analytics
      namespace = var.enable_log_analytics ? oci_log_analytics_namespace.library_analytics[0].namespace : null
    }
  }
}

# ====================================
# Integration Points Outputs
# ====================================

output "integration_endpoints" {
  description = "Integration endpoints for external monitoring systems"
  value = {
    # Log Analytics Integration
    log_analytics = var.enable_log_analytics ? {
      namespace = oci_log_analytics_namespace.library_analytics[0].namespace
      entity_id = oci_log_analytics_log_analytics_entity.app_entity[0].id
      log_groups = {
        app = oci_logging_log_group.app_logs.id
        infrastructure = oci_logging_log_group.infrastructure_logs.id
        security = oci_logging_log_group.security_logs.id
      }
    } : null
    
    # APM Integration
    apm = var.enable_apm ? {
      domain_id = oci_apm_apm_domain.app_apm[0].id
      data_upload_endpoint = oci_apm_apm_domain.app_apm[0].data_upload_endpoint
    } : null
    
    # Health Check Integration
    health_checks = {
      application_endpoint = "${var.health_check_protocol}://${var.load_balancer_ip}:${var.health_check_port}${var.health_check_path}"
      api_endpoint = "${var.health_check_protocol}://${var.load_balancer_ip}:${var.health_check_port}/api/v1/health/"
    }
    
    # Alert Integration
    notification_topic = var.notification_topic_id
    
    # Storage Integration
    log_archive = var.enable_log_archival ? {
      bucket_name = oci_objectstorage_bucket.log_archive_bucket[0].name
      namespace = oci_objectstorage_bucket.log_archive_bucket[0].namespace
    } : null
  }
}

# ====================================
# Alarm Thresholds Summary
# ====================================

output "alarm_thresholds" {
  description = "Summary of all alarm thresholds configured"
  value = {
    cpu_utilization_percent = var.cpu_alarm_threshold
    memory_utilization_percent = var.memory_alarm_threshold
    response_time_ms = var.response_time_threshold_ms
    api_error_rate_percent = var.api_error_rate_threshold
    db_connection_count = var.db_connection_threshold
    failed_login_attempts = var.failed_login_threshold
    suspicious_activity_count = var.suspicious_activity_threshold
  }
}

# ====================================
# Monitoring URLs and Access Points
# ====================================

output "monitoring_urls" {
  description = "URLs for accessing monitoring dashboards and interfaces"
  value = {
    oci_console_monitoring = "https://cloud.oracle.com/monitoring/alarms"
    oci_console_logging = "https://cloud.oracle.com/logging/logs"
    oci_console_apm = var.enable_apm ? "https://cloud.oracle.com/apm/domains" : null
    health_check_status = "https://cloud.oracle.com/health-checks/http-monitors"
    dashboards = var.create_dashboards ? "https://cloud.oracle.com/management-dashboards" : null
  }
}

# ====================================
# Compliance and Audit Outputs
# ====================================

output "compliance_configuration" {
  description = "Compliance and audit configuration details"
  value = {
    audit_logging_enabled = true
    log_retention_days = var.log_retention_days
    audit_log_retention_days = var.audit_log_retention_days
    security_monitoring_enabled = var.enable_security_monitoring
    compliance_standards = var.compliance_standards
    audit_trail_retention_days = var.audit_trail_retention_days
  }
}

# ====================================
# Cost Monitoring Outputs
# ====================================

output "cost_monitoring_configuration" {
  description = "Cost monitoring configuration details"
  value = {
    enabled = var.enable_cost_monitoring
    monthly_budget_threshold = var.monthly_budget_threshold
    alert_percentage = var.cost_alert_percentage
  }
}

# ====================================
# Terraform and Deployment Outputs
# ====================================

output "terraform_workspace" {
  description = "Current Terraform workspace"
  value       = terraform.workspace
}

output "deployment_timestamp" {
  description = "Timestamp of monitoring deployment"
  value       = timestamp()
}

output "monitoring_module_version" {
  description = "Version of the monitoring module"
  value       = "1.0.0"
}

# ====================================
# Summary Output for Status Reporting
# ====================================

output "monitoring_summary" {
  description = "Complete summary of monitoring infrastructure"
  value = {
    # Core Components
    log_groups_created = 3
    alarms_configured = 8
    health_checks_active = 2
    dashboards_created = var.create_dashboards ? 2 : 0
    
    # Feature Status
    features = {
      log_analytics = var.enable_log_analytics
      apm = var.enable_apm
      monitoring_alarms = var.enable_monitoring_alarms
      dashboards = var.create_dashboards
      health_checks = true
      log_archival = var.enable_log_archival
      security_monitoring = var.enable_security_monitoring
      cost_monitoring = var.enable_cost_monitoring
    }
    
    # Resource Counts
    resources = {
      log_groups = 3
      logs = 8
      alarms = 8
      health_checks = 2
      dashboards = var.create_dashboards ? 2 : 0
      event_rules = 2
      apm_domains = var.enable_apm ? 1 : 0
    }
    
    # Integration Points
    integrations = {
      notification_topic = var.notification_topic_id != ""
      load_balancer = var.load_balancer_id != ""
      database = var.database_id != ""
      waf = var.waf_policy_id != ""
      object_storage = var.enable_log_archival
    }
  }
}
