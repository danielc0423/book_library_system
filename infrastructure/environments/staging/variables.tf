# ====================================
# Staging Environment Variables
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# Provider Configuration Variables
# ====================================

variable "tenancy_ocid" {
  description = "OCID of the tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID of the user"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the user's API key"
  type        = string
}

variable "private_key_path" {
  description = "Path to the user's private key file"
  type        = string
}

variable "region" {
  description = "OCI region"
  type        = string
  default     = "us-ashburn-1"
}

variable "compartment_ocid" {
  description = "OCID of the compartment"
  type        = string
}

# ====================================
# Staging Environment Configuration
# ====================================

variable "environment_name" {
  description = "Name of the environment"
  type        = string
  default     = "staging"
  
  validation {
    condition     = var.environment_name == "staging"
    error_message = "This configuration is specifically for staging environment."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "library-system"
}

variable "cost_center" {
  description = "Cost center for billing and tagging"
  type        = string
  default     = "Engineering"
}

variable "owner_email" {
  description = "Email of the environment owner"
  type        = string
  default     = "qa-team@company.com"
}

# ====================================
# Domain and SSL Configuration
# ====================================

variable "staging_domain_name" {
  description = "Domain name for staging environment"
  type        = string
  default     = "staging.library.company.com"
}

variable "enable_custom_domain" {
  description = "Enable custom domain configuration"
  type        = bool
  default     = true
}

variable "ssl_certificate_source" {
  description = "Source of SSL certificate (letsencrypt, custom, oci)"
  type        = string
  default     = "letsencrypt"
  
  validation {
    condition     = contains(["letsencrypt", "custom", "oci"], var.ssl_certificate_source)
    error_message = "SSL certificate source must be letsencrypt, custom, or oci."
  }
}

# ====================================
# Database Configuration
# ====================================

variable "db_admin_password" {
  description = "Admin password for the staging database"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.db_admin_password) >= 14
    error_message = "Database admin password must be at least 14 characters long for staging."
  }
}

variable "db_name" {
  description = "Name of the staging database"
  type        = string
  default     = "libstagedb"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,7}$", var.db_name))
    error_message = "Database name must start with a letter and be 1-8 characters long."
  }
}

variable "db_backup_schedule" {
  description = "Database backup schedule (cron format)"
  type        = string
  default     = "0 2 * * *"  # Daily at 2 AM
}

variable "db_maintenance_window" {
  description = "Database maintenance window configuration"
  type = object({
    day_of_week = string
    start_time  = string
    duration    = number
  })
  default = {
    day_of_week = "SUNDAY"
    start_time  = "02:00"
    duration    = 4
  }
}

# ====================================
# SSH Access Configuration
# ====================================

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
  sensitive   = true
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed SSH access"
  type        = list(string)
  default     = []  # Should be specified in tfvars
}

variable "enable_ssh_key_rotation" {
  description = "Enable automatic SSH key rotation"
  type        = bool
  default     = true
}

variable "ssh_key_rotation_days" {
  description = "Number of days between SSH key rotations"
  type        = number
  default     = 90
  
  validation {
    condition     = var.ssh_key_rotation_days >= 30 && var.ssh_key_rotation_days <= 365
    error_message = "SSH key rotation must be between 30 and 365 days."
  }
}

# ====================================
# Network Security Configuration
# ====================================

variable "enable_network_security_scanning" {
  description = "Enable network security scanning"
  type        = bool
  default     = true
}

variable "allowed_external_cidrs" {
  description = "List of external CIDR blocks allowed access"
  type        = list(string)
  default     = []
}

variable "enable_ddos_protection" {
  description = "Enable DDoS protection"
  type        = bool
  default     = true
}

variable "firewall_rules" {
  description = "Custom firewall rules for staging"
  type = list(object({
    name        = string
    direction   = string
    protocol    = string
    source      = string
    destination = string
    port_range  = string
    action      = string
    priority    = number
  }))
  default = []
}

# ====================================
# Performance and Scaling Configuration
# ====================================

variable "performance_tier" {
  description = "Performance tier for staging environment"
  type        = string
  default     = "standard"
  
  validation {
    condition     = contains(["basic", "standard", "premium"], var.performance_tier)
    error_message = "Performance tier must be basic, standard, or premium."
  }
}

variable "auto_scaling_policy" {
  description = "Auto scaling policy configuration"
  type = object({
    scale_out_cpu_threshold    = number
    scale_in_cpu_threshold     = number
    scale_out_memory_threshold = number
    scale_in_memory_threshold  = number
    cooldown_minutes          = number
  })
  default = {
    scale_out_cpu_threshold    = 70
    scale_in_cpu_threshold     = 30
    scale_out_memory_threshold = 75
    scale_in_memory_threshold  = 35
    cooldown_minutes          = 5
  }
}

variable "load_testing_enabled" {
  description = "Enable load testing configuration"
  type        = bool
  default     = true
}

variable "expected_peak_users" {
  description = "Expected peak concurrent users for capacity planning"
  type        = number
  default     = 500
  
  validation {
    condition     = var.expected_peak_users >= 100 && var.expected_peak_users <= 10000
    error_message = "Expected peak users must be between 100 and 10000."
  }
}

# ====================================
# Monitoring and Alerting Configuration
# ====================================

variable "monitoring_level" {
  description = "Level of monitoring (basic, standard, comprehensive)"
  type        = string
  default     = "comprehensive"
  
  validation {
    condition     = contains(["basic", "standard", "comprehensive"], var.monitoring_level)
    error_message = "Monitoring level must be basic, standard, or comprehensive."
  }
}

variable "alert_notification_emails" {
  description = "Email addresses for alert notifications"
  type        = list(string)
  default     = []
}

variable "alert_severity_levels" {
  description = "Alert severity levels to enable"
  type        = list(string)
  default     = ["WARNING", "CRITICAL"]
  
  validation {
    condition = alltrue([
      for level in var.alert_severity_levels : contains(["INFO", "WARNING", "CRITICAL"], level)
    ])
    error_message = "Alert severity levels must be INFO, WARNING, or CRITICAL."
  }
}

variable "custom_metrics" {
  description = "Custom metrics to monitor"
  type = list(object({
    name        = string
    namespace   = string
    query       = string
    threshold   = number
    comparison  = string
    severity    = string
  }))
  default = []
}

# ====================================
# Application Configuration
# ====================================

variable "django_debug_mode" {
  description = "Enable Django debug mode (should be false for staging)"
  type        = bool
  default     = false
}

variable "django_secret_key" {
  description = "Django secret key for staging"
  type        = string
  sensitive   = true
}

variable "allowed_hosts" {
  description = "Allowed hosts for Django application"
  type        = list(string)
  default     = []  # Should be specified in tfvars
}

variable "cors_allowed_origins" {
  description = "CORS allowed origins for staging"
  type        = list(string)
  default     = []
}

variable "api_rate_limiting" {
  description = "API rate limiting configuration"
  type = object({
    enabled           = bool
    requests_per_hour = number
    burst_limit      = number
  })
  default = {
    enabled           = true
    requests_per_hour = 1000
    burst_limit      = 50
  }
}

# ====================================
# Data Management Configuration
# ====================================

variable "enable_data_masking" {
  description = "Enable data masking for sensitive information"
  type        = bool
  default     = true
}

variable "data_retention_policy" {
  description = "Data retention policy configuration"
  type = object({
    application_logs_days = number
    audit_logs_days      = number
    user_data_days       = number
    metrics_days         = number
  })
  default = {
    application_logs_days = 30
    audit_logs_days      = 90
    user_data_days       = 365
    metrics_days         = 93
  }
}

variable "backup_strategy" {
  description = "Backup strategy configuration"
  type = object({
    database_backup_frequency   = string
    application_backup_frequency = string
    retention_period_days      = number
    cross_region_backup        = bool
  })
  default = {
    database_backup_frequency   = "daily"
    application_backup_frequency = "weekly"
    retention_period_days      = 30
    cross_region_backup        = false
  }
}

# ====================================
# Testing Configuration
# ====================================

variable "enable_test_automation" {
  description = "Enable test automation features"
  type        = bool
  default     = true
}

variable "test_data_configuration" {
  description = "Test data configuration"
  type = object({
    load_production_snapshot = bool
    generate_synthetic_data  = bool
    data_volume_percentage   = number
    anonymize_data          = bool
  })
  default = {
    load_production_snapshot = false
    generate_synthetic_data  = true
    data_volume_percentage   = 80
    anonymize_data          = true
  }
}

variable "qa_testing_tools" {
  description = "QA testing tools to install"
  type        = list(string)
  default = [
    "selenium",
    "postman",
    "jmeter",
    "sonarqube"
  ]
}

# ====================================
# Integration Configuration
# ====================================

variable "external_integrations" {
  description = "External integration configurations"
  type = map(object({
    enabled    = bool
    endpoint   = string
    auth_type  = string
    timeout_ms = number
  }))
  default = {}
  sensitive = true
}

variable "enable_api_mocking" {
  description = "Enable API mocking for external services"
  type        = bool
  default     = true
}

variable "mock_service_endpoints" {
  description = "Mock service endpoint configurations"
  type = map(object({
    original_endpoint = string
    mock_endpoint    = string
    response_delay_ms = number
  }))
  default = {}
}

# ====================================
# Compliance and Security Configuration
# ====================================

variable "compliance_standards" {
  description = "Compliance standards to enforce"
  type        = list(string)
  default     = ["SOC2", "GDPR", "PCI-DSS"]
}

variable "security_scanning_schedule" {
  description = "Security scanning schedule (cron format)"
  type        = string
  default     = "0 3 * * 1"  # Weekly on Monday at 3 AM
}

variable "vulnerability_scan_enabled" {
  description = "Enable vulnerability scanning"
  type        = bool
  default     = true
}

variable "penetration_testing_schedule" {
  description = "Penetration testing schedule configuration"
  type = object({
    enabled   = bool
    frequency = string
    scope     = list(string)
  })
  default = {
    enabled   = true
    frequency = "monthly"
    scope     = ["web", "api", "infrastructure"]
  }
}

# ====================================
# Cost Management Configuration
# ====================================

variable "cost_management" {
  description = "Cost management configuration"
  type = object({
    monthly_budget_limit    = number
    cost_alert_thresholds  = list(number)
    auto_scaling_cost_limit = number
    resource_tagging_required = bool
  })
  default = {
    monthly_budget_limit    = 2000
    cost_alert_thresholds  = [50, 75, 90]
    auto_scaling_cost_limit = 500
    resource_tagging_required = true
  }
}

variable "resource_optimization" {
  description = "Resource optimization settings"
  type = object({
    enable_rightsizing_recommendations = bool
    enable_unused_resource_detection   = bool
    enable_cost_anomaly_detection      = bool
  })
  default = {
    enable_rightsizing_recommendations = true
    enable_unused_resource_detection   = true
    enable_cost_anomaly_detection      = true
  }
}

# ====================================
# Disaster Recovery Configuration
# ====================================

variable "disaster_recovery" {
  description = "Disaster recovery configuration"
  type = object({
    enabled                = bool
    backup_region         = string
    rto_hours             = number
    rpo_hours             = number
    automated_failover    = bool
    cross_region_replication = bool
  })
  default = {
    enabled                = true
    backup_region         = "us-phoenix-1"
    rto_hours             = 4
    rpo_hours             = 1
    automated_failover    = false
    cross_region_replication = false
  }
}

# ====================================
# Environment Lifecycle Configuration
# ====================================

variable "environment_lifecycle" {
  description = "Environment lifecycle management"
  type = object({
    auto_refresh_enabled       = bool
    refresh_schedule          = string
    data_refresh_source       = string
    notification_before_refresh = number
  })
  default = {
    auto_refresh_enabled       = true
    refresh_schedule          = "0 2 * * 0"  # Weekly on Sunday at 2 AM
    data_refresh_source       = "production"
    notification_before_refresh = 24  # hours
  }
}

# ====================================
# Object Storage Configuration
# ====================================

variable "object_storage_namespace" {
  description = "Object storage namespace"
  type        = string
}

variable "staging_storage_configuration" {
  description = "Staging storage configuration"
  type = object({
    static_files_bucket = string
    media_files_bucket  = string
    backup_bucket      = string
    logs_bucket        = string
    archive_bucket     = string
  })
  default = {
    static_files_bucket = "staging-library-static"
    media_files_bucket  = "staging-library-media"
    backup_bucket      = "staging-library-backups"
    logs_bucket        = "staging-library-logs"
    archive_bucket     = "staging-library-archive"
  }
}

# ====================================
# User Access Management
# ====================================

variable "user_access_groups" {
  description = "User access groups and permissions"
  type = map(object({
    members           = list(string)
    permissions       = list(string)
    ssh_access        = bool
    admin_access      = bool
    temporary_access  = bool
    access_duration_hours = number
  }))
  default = {}
}

variable "access_review_schedule" {
  description = "Access review schedule configuration"
  type = object({
    enabled   = bool
    frequency = string
    reviewers = list(string)
  })
  default = {
    enabled   = true
    frequency = "monthly"
    reviewers = []
  }
}

# ====================================
# Custom Tags
# ====================================

variable "custom_tags" {
  description = "Custom tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "staging"
    Purpose     = "pre-production-testing"
    DataClass   = "test"
    Criticality = "medium"
    Compliance  = "required"
  }
}

# ====================================
# Feature Flags
# ====================================

variable "feature_flags" {
  description = "Feature flags for staging environment testing"
  type        = map(bool)
  default = {
    "enable_new_ui"                = true
    "enable_advanced_search"       = true
    "enable_book_recommendations"  = true
    "enable_social_features"       = true
    "enable_mobile_app_api"        = true
    "enable_analytics_dashboard"   = true
    "enable_ai_features"           = false
    "enable_experimental_features" = true
  }
}
