# ====================================
# Monitoring Module Variables
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# General Configuration Variables
# ====================================

variable "compartment_ocid" {
  description = "The OCID of the compartment where monitoring resources will be created"
  type        = string
}

variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

# ====================================
# Resource Dependencies
# ====================================

variable "vcn_id" {
  description = "The OCID of the VCN for network monitoring"
  type        = string
}

variable "load_balancer_id" {
  description = "The OCID of the load balancer"
  type        = string
  default     = ""
}

variable "load_balancer_ip" {
  description = "IP address of the load balancer for health checks"
  type        = string
  default     = ""
}

variable "instance_pool_id" {
  description = "The OCID of the instance pool"
  type        = string
  default     = ""
}

variable "database_id" {
  description = "The OCID of the autonomous database"
  type        = string
  default     = ""
}

variable "notification_topic_id" {
  description = "The OCID of the notification topic for alerts"
  type        = string
}

variable "waf_policy_id" {
  description = "The OCID of the WAF policy for security monitoring"
  type        = string
  default     = ""
}

variable "object_storage_namespace" {
  description = "Object storage namespace for log archival"
  type        = string
}

# ====================================
# Log Analytics Configuration
# ====================================

variable "enable_log_analytics" {
  description = "Enable OCI Log Analytics service"
  type        = bool
  default     = true
}

variable "log_analytics_namespace" {
  description = "Log Analytics namespace (auto-generated if not specified)"
  type        = string
  default     = ""
}

# ====================================
# Logging Configuration
# ====================================

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
  
  validation {
    condition     = var.log_retention_days >= 1 && var.log_retention_days <= 365
    error_message = "Log retention must be between 1 and 365 days."
  }
}

variable "audit_log_retention_days" {
  description = "Number of days to retain audit logs"
  type        = number
  default     = 90
  
  validation {
    condition     = var.audit_log_retention_days >= 30 && var.audit_log_retention_days <= 2555
    error_message = "Audit log retention must be between 30 and 2555 days."
  }
}

variable "enable_log_archival" {
  description = "Enable log archival to object storage"
  type        = bool
  default     = true
}

variable "log_archive_retention_days" {
  description = "Number of days to retain archived logs"
  type        = number
  default     = 2555
  
  validation {
    condition     = var.log_archive_retention_days >= 30 && var.log_archive_retention_days <= 36500
    error_message = "Log archive retention must be between 30 and 36500 days."
  }
}

# ====================================
# Monitoring Alarms Configuration
# ====================================

variable "enable_monitoring_alarms" {
  description = "Enable monitoring alarms"
  type        = bool
  default     = true
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization threshold for alarms (percentage)"
  type        = number
  default     = 80
  
  validation {
    condition     = var.cpu_alarm_threshold >= 1 && var.cpu_alarm_threshold <= 100
    error_message = "CPU alarm threshold must be between 1 and 100."
  }
}

variable "memory_alarm_threshold" {
  description = "Memory utilization threshold for alarms (percentage)"
  type        = number
  default     = 85
  
  validation {
    condition     = var.memory_alarm_threshold >= 1 && var.memory_alarm_threshold <= 100
    error_message = "Memory alarm threshold must be between 1 and 100."
  }
}

variable "response_time_threshold_ms" {
  description = "Response time threshold for alarms (milliseconds)"
  type        = number
  default     = 5000
  
  validation {
    condition     = var.response_time_threshold_ms >= 100 && var.response_time_threshold_ms <= 60000
    error_message = "Response time threshold must be between 100 and 60000 ms."
  }
}

variable "api_error_rate_threshold" {
  description = "API error rate threshold for alarms (percentage)"
  type        = number
  default     = 5
  
  validation {
    condition     = var.api_error_rate_threshold >= 0 && var.api_error_rate_threshold <= 100
    error_message = "API error rate threshold must be between 0 and 100."
  }
}

variable "db_connection_threshold" {
  description = "Database connection threshold for alarms"
  type        = number
  default     = 80
  
  validation {
    condition     = var.db_connection_threshold >= 1 && var.db_connection_threshold <= 1000
    error_message = "Database connection threshold must be between 1 and 1000."
  }
}

# ====================================
# Health Check Configuration
# ====================================

variable "health_check_interval_seconds" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
  
  validation {
    condition     = var.health_check_interval_seconds >= 10 && var.health_check_interval_seconds <= 300
    error_message = "Health check interval must be between 10 and 300 seconds."
  }
}

variable "health_check_timeout_seconds" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 10
  
  validation {
    condition     = var.health_check_timeout_seconds >= 1 && var.health_check_timeout_seconds <= 60
    error_message = "Health check timeout must be between 1 and 60 seconds."
  }
}

variable "health_check_protocol" {
  description = "Health check protocol"
  type        = string
  default     = "HTTPS"
  
  validation {
    condition     = contains(["HTTP", "HTTPS"], var.health_check_protocol)
    error_message = "Health check protocol must be HTTP or HTTPS."
  }
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/health/"
}

variable "health_check_port" {
  description = "Health check port"
  type        = number
  default     = 443
  
  validation {
    condition     = var.health_check_port >= 1 && var.health_check_port <= 65535
    error_message = "Health check port must be between 1 and 65535."
  }
}

# ====================================
# Dashboard Configuration
# ====================================

variable "create_dashboards" {
  description = "Create monitoring dashboards"
  type        = bool
  default     = true
}

variable "dashboard_refresh_interval" {
  description = "Dashboard refresh interval in seconds"
  type        = number
  default     = 300
  
  validation {
    condition     = var.dashboard_refresh_interval >= 60 && var.dashboard_refresh_interval <= 3600
    error_message = "Dashboard refresh interval must be between 60 and 3600 seconds."
  }
}

# ====================================
# Application Performance Monitoring (APM)
# ====================================

variable "enable_apm" {
  description = "Enable Application Performance Monitoring"
  type        = bool
  default     = true
}

variable "apm_free_tier" {
  description = "Use APM free tier"
  type        = bool
  default     = true
}

variable "apm_data_upload_endpoint" {
  description = "APM data upload endpoint"
  type        = string
  default     = ""
}

# ====================================
# Synthetic Monitoring
# ====================================

variable "enable_synthetic_monitoring" {
  description = "Enable synthetic monitoring"
  type        = bool
  default     = true
}

variable "synthetic_monitor_locations" {
  description = "List of locations for synthetic monitoring"
  type        = list(string)
  default     = ["us-ashburn-1", "us-phoenix-1"]
}

# ====================================
# Custom Metrics Configuration
# ====================================

variable "custom_metrics_namespace" {
  description = "Namespace for custom application metrics"
  type        = string
  default     = "library_system_metrics"
}

variable "enable_custom_metrics" {
  description = "Enable custom application metrics"
  type        = bool
  default     = true
}

variable "metrics_retention_days" {
  description = "Number of days to retain metrics data"
  type        = number
  default     = 93
  
  validation {
    condition     = var.metrics_retention_days >= 1 && var.metrics_retention_days <= 93
    error_message = "Metrics retention must be between 1 and 93 days."
  }
}

# ====================================
# Event Rules Configuration
# ====================================

variable "enable_event_rules" {
  description = "Enable event rules for infrastructure changes"
  type        = bool
  default     = true
}

variable "critical_events_only" {
  description = "Only create rules for critical events"
  type        = bool
  default     = false
}

variable "event_rule_conditions" {
  description = "Custom event rule conditions"
  type        = list(object({
    event_type = string
    condition  = string
    severity   = string
  }))
  default = []
}

# ====================================
# Log Shipping Configuration
# ====================================

variable "enable_log_shipping" {
  description = "Enable log shipping to external systems"
  type        = bool
  default     = false
}

variable "log_shipping_destination" {
  description = "Destination for log shipping (splunk, elasticsearch, etc.)"
  type        = string
  default     = ""
}

variable "log_shipping_endpoint" {
  description = "Endpoint URL for log shipping"
  type        = string
  default     = ""
}

variable "log_shipping_authentication" {
  description = "Authentication configuration for log shipping"
  type = object({
    type = string
    credentials = map(string)
  })
  default = {
    type = "none"
    credentials = {}
  }
  sensitive = true
}

# ====================================
# Security Monitoring Configuration
# ====================================

variable "enable_security_monitoring" {
  description = "Enable security monitoring and alerting"
  type        = bool
  default     = true
}

variable "security_alert_severity" {
  description = "Minimum severity level for security alerts"
  type        = string
  default     = "WARNING"
  
  validation {
    condition     = contains(["INFO", "WARNING", "CRITICAL"], var.security_alert_severity)
    error_message = "Security alert severity must be INFO, WARNING, or CRITICAL."
  }
}

variable "failed_login_threshold" {
  description = "Threshold for failed login attempts before alerting"
  type        = number
  default     = 5
  
  validation {
    condition     = var.failed_login_threshold >= 1 && var.failed_login_threshold <= 100
    error_message = "Failed login threshold must be between 1 and 100."
  }
}

variable "suspicious_activity_threshold" {
  description = "Threshold for suspicious activity detection"
  type        = number
  default     = 10
  
  validation {
    condition     = var.suspicious_activity_threshold >= 1 && var.suspicious_activity_threshold <= 1000
    error_message = "Suspicious activity threshold must be between 1 and 1000."
  }
}

# ====================================
# Performance Monitoring Configuration
# ====================================

variable "performance_monitoring_interval" {
  description = "Performance monitoring data collection interval in seconds"
  type        = number
  default     = 60
  
  validation {
    condition     = var.performance_monitoring_interval >= 10 && var.performance_monitoring_interval <= 300
    error_message = "Performance monitoring interval must be between 10 and 300 seconds."
  }
}

variable "detailed_monitoring" {
  description = "Enable detailed monitoring (higher frequency, more metrics)"
  type        = bool
  default     = false
}

variable "enable_profiling" {
  description = "Enable application profiling"
  type        = bool
  default     = false
}

# ====================================
# Cost Monitoring Configuration
# ====================================

variable "enable_cost_monitoring" {
  description = "Enable cost monitoring and alerts"
  type        = bool
  default     = true
}

variable "monthly_budget_threshold" {
  description = "Monthly budget threshold for cost alerts (USD)"
  type        = number
  default     = 1000
  
  validation {
    condition     = var.monthly_budget_threshold >= 0
    error_message = "Monthly budget threshold must be non-negative."
  }
}

variable "cost_alert_percentage" {
  description = "Percentage of budget to trigger cost alert"
  type        = number
  default     = 80
  
  validation {
    condition     = var.cost_alert_percentage >= 1 && var.cost_alert_percentage <= 100
    error_message = "Cost alert percentage must be between 1 and 100."
  }
}

# ====================================
# Compliance and Audit Configuration
# ====================================

variable "enable_compliance_monitoring" {
  description = "Enable compliance monitoring"
  type        = bool
  default     = true
}

variable "compliance_standards" {
  description = "List of compliance standards to monitor"
  type        = list(string)
  default     = ["PCI-DSS", "SOC2", "GDPR"]
}

variable "audit_trail_retention_days" {
  description = "Number of days to retain audit trail"
  type        = number
  default     = 2555
  
  validation {
    condition     = var.audit_trail_retention_days >= 90 && var.audit_trail_retention_days <= 36500
    error_message = "Audit trail retention must be between 90 and 36500 days."
  }
}

# ====================================
# Integration Configuration
# ====================================

variable "enable_third_party_integrations" {
  description = "Enable third-party monitoring integrations"
  type        = bool
  default     = false
}

variable "third_party_endpoints" {
  description = "Configuration for third-party monitoring endpoints"
  type = list(object({
    name = string
    url = string
    authentication = object({
      type = string
      credentials = map(string)
    })
  }))
  default = []
  sensitive = true
}

# ====================================
# Notification Configuration
# ====================================

variable "notification_channels" {
  description = "List of notification channels for alerts"
  type = list(object({
    type = string
    destination = string
    severity_filter = list(string)
  }))
  default = []
}

variable "escalation_policy" {
  description = "Escalation policy for critical alerts"
  type = object({
    enabled = bool
    escalation_delay_minutes = number
    escalation_channels = list(string)
  })
  default = {
    enabled = false
    escalation_delay_minutes = 15
    escalation_channels = []
  }
}

# ====================================
# Maintenance and Backup Configuration
# ====================================

variable "monitoring_backup_enabled" {
  description = "Enable backup of monitoring configurations"
  type        = bool
  default     = true
}

variable "monitoring_backup_schedule" {
  description = "Cron schedule for monitoring configuration backups"
  type        = string
  default     = "0 2 * * 0"  # Weekly at 2 AM on Sunday
}

variable "maintenance_window" {
  description = "Maintenance window for monitoring infrastructure updates"
  type = object({
    day_of_week = string
    start_time = string
    duration_hours = number
  })
  default = {
    day_of_week = "Sunday"
    start_time = "02:00"
    duration_hours = 4
  }
}

# ====================================
# Development and Testing Configuration
# ====================================

variable "enable_debug_logging" {
  description = "Enable debug logging for monitoring components"
  type        = bool
  default     = false
}

variable "test_alerts_enabled" {
  description = "Enable test alerts for validation"
  type        = bool
  default     = false
}

variable "monitoring_test_schedule" {
  description = "Schedule for monitoring system tests"
  type        = string
  default     = "0 1 * * 1"  # Weekly at 1 AM on Monday
}
