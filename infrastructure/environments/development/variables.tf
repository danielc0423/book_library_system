# ====================================
# Development Environment Variables
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
# Development Environment Configuration
# ====================================

variable "environment_name" {
  description = "Name of the environment"
  type        = string
  default     = "development"
  
  validation {
    condition     = var.environment_name == "development"
    error_message = "This configuration is specifically for development environment."
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
  default     = "devops@company.com"
}

# ====================================
# Database Configuration
# ====================================

variable "db_admin_password" {
  description = "Admin password for the development database"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.db_admin_password) >= 12
    error_message = "Database admin password must be at least 12 characters long."
  }
}

variable "db_name" {
  description = "Name of the development database"
  type        = string
  default     = "libdevdb"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,7}$", var.db_name))
    error_message = "Database name must start with a letter and be 1-8 characters long."
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

variable "developer_ip_addresses" {
  description = "List of developer IP addresses allowed SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Allow from anywhere in development
}

# ====================================
# Development-Specific Settings
# ====================================

variable "enable_debug_mode" {
  description = "Enable debug mode for applications"
  type        = bool
  default     = true
}

variable "enable_hot_reload" {
  description = "Enable hot reload for development"
  type        = bool
  default     = true
}

variable "install_dev_dependencies" {
  description = "Install development dependencies"
  type        = bool
  default     = true
}

variable "dev_tools_to_install" {
  description = "List of development tools to install"
  type        = list(string)
  default = [
    "git",
    "vim",
    "htop",
    "curl",
    "wget",
    "python3-dev",
    "python3-pip",
    "nodejs",
    "npm"
  ]
}

# ====================================
# Cost Control Settings
# ====================================

variable "max_monthly_spend" {
  description = "Maximum monthly spend for development environment (USD)"
  type        = number
  default     = 500
  
  validation {
    condition     = var.max_monthly_spend >= 100 && var.max_monthly_spend <= 2000
    error_message = "Monthly spend limit must be between $100 and $2000 for development."
  }
}

variable "auto_shutdown_enabled" {
  description = "Enable automatic shutdown of resources during non-business hours"
  type        = bool
  default     = true
}

variable "business_hours" {
  description = "Business hours configuration for auto-shutdown"
  type = object({
    start_hour = number
    end_hour   = number
    timezone   = string
    weekdays_only = bool
  })
  default = {
    start_hour = 8
    end_hour = 18
    timezone = "America/New_York"
    weekdays_only = true
  }
}

# ====================================
# Network Configuration
# ====================================

variable "allow_internet_access" {
  description = "Allow internet access from private subnets (for development)"
  type        = bool
  default     = true
}

variable "custom_security_rules" {
  description = "Custom security rules for development access"
  type = list(object({
    direction   = string
    protocol    = string
    source      = string
    destination = string
    port_range  = string
    description = string
  }))
  default = []
}

# ====================================
# Monitoring and Logging
# ====================================

variable "log_level" {
  description = "Log level for development environment"
  type        = string
  default     = "DEBUG"
  
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR"], var.log_level)
    error_message = "Log level must be DEBUG, INFO, WARNING, or ERROR."
  }
}

variable "enable_performance_monitoring" {
  description = "Enable detailed performance monitoring"
  type        = bool
  default     = false  # Disabled for cost savings in development
}

variable "metrics_collection_interval" {
  description = "Metrics collection interval in seconds"
  type        = number
  default     = 300  # 5 minutes for development
  
  validation {
    condition     = var.metrics_collection_interval >= 60 && var.metrics_collection_interval <= 3600
    error_message = "Metrics collection interval must be between 60 and 3600 seconds."
  }
}

# ====================================
# Application Configuration
# ====================================

variable "django_debug_mode" {
  description = "Enable Django debug mode"
  type        = bool
  default     = true
}

variable "django_secret_key" {
  description = "Django secret key for development"
  type        = string
  sensitive   = true
  default     = "dev-secret-key-change-in-production"
}

variable "allowed_hosts" {
  description = "Allowed hosts for Django application"
  type        = list(string)
  default     = ["*"]  # Allow all hosts in development
}

variable "cors_allowed_origins" {
  description = "CORS allowed origins for development"
  type        = list(string)
  default     = ["http://localhost:3000", "http://localhost:8080"]
}

# ====================================
# Testing Configuration
# ====================================

variable "enable_test_data" {
  description = "Enable loading of test data"
  type        = bool
  default     = true
}

variable "test_user_count" {
  description = "Number of test users to create"
  type        = number
  default     = 100
  
  validation {
    condition     = var.test_user_count >= 10 && var.test_user_count <= 1000
    error_message = "Test user count must be between 10 and 1000."
  }
}

variable "test_book_count" {
  description = "Number of test books to create"
  type        = number
  default     = 500
  
  validation {
    condition     = var.test_book_count >= 100 && var.test_book_count <= 5000
    error_message = "Test book count must be between 100 and 5000."
  }
}

# ====================================
# Backup and Recovery
# ====================================

variable "backup_frequency" {
  description = "Backup frequency for development environment"
  type        = string
  default     = "weekly"
  
  validation {
    condition     = contains(["daily", "weekly", "monthly"], var.backup_frequency)
    error_message = "Backup frequency must be daily, weekly, or monthly."
  }
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 30
    error_message = "Backup retention must be between 1 and 30 days for development."
  }
}

# ====================================
# External Service Configuration
# ====================================

variable "external_services" {
  description = "Configuration for external services"
  type = object({
    email_service = object({
      enabled = bool
      provider = string
      api_key = string
    })
    storage_service = object({
      enabled = bool
      bucket_name = string
    })
    cdn_service = object({
      enabled = bool
      distribution_domain = string
    })
  })
  default = {
    email_service = {
      enabled = false
      provider = "mock"
      api_key = "mock-api-key"
    }
    storage_service = {
      enabled = false
      bucket_name = "dev-library-storage"
    }
    cdn_service = {
      enabled = false
      distribution_domain = "dev-cdn.library.local"
    }
  }
  sensitive = true
}

# ====================================
# Object Storage Configuration
# ====================================

variable "object_storage_namespace" {
  description = "Object storage namespace"
  type        = string
}

variable "create_dev_buckets" {
  description = "Create development-specific storage buckets"
  type        = bool
  default     = true
}

variable "dev_bucket_names" {
  description = "Names of development buckets to create"
  type        = list(string)
  default = [
    "dev-library-static",
    "dev-library-media",
    "dev-library-backups",
    "dev-library-logs"
  ]
}

# ====================================
# Integration Testing Configuration
# ====================================

variable "enable_integration_tests" {
  description = "Enable integration testing environment"
  type        = bool
  default     = true
}

variable "test_environment_config" {
  description = "Test environment configuration"
  type = object({
    selenium_grid_enabled = bool
    api_testing_enabled = bool
    load_testing_enabled = bool
    security_testing_enabled = bool
  })
  default = {
    selenium_grid_enabled = false
    api_testing_enabled = true
    load_testing_enabled = false
    security_testing_enabled = false
  }
}

# ====================================
# Developer Access Configuration
# ====================================

variable "developer_groups" {
  description = "Developer groups and their access levels"
  type = map(object({
    members = list(string)
    permissions = list(string)
    ssh_access = bool
    admin_access = bool
  }))
  default = {
    "backend-developers" = {
      members = []
      permissions = ["compute:*", "database:read", "logging:read"]
      ssh_access = true
      admin_access = false
    }
    "frontend-developers" = {
      members = []
      permissions = ["compute:read", "logging:read"]
      ssh_access = false
      admin_access = false
    }
    "devops-team" = {
      members = []
      permissions = ["*:*"]
      ssh_access = true
      admin_access = true
    }
  }
}

# ====================================
# Environment Lifecycle Configuration
# ====================================

variable "environment_lifecycle" {
  description = "Environment lifecycle configuration"
  type = object({
    auto_destroy_enabled = bool
    max_age_days = number
    warning_days_before_destroy = number
    preserve_data = bool
  })
  default = {
    auto_destroy_enabled = false
    max_age_days = 30
    warning_days_before_destroy = 7
    preserve_data = false
  }
}

variable "scheduled_maintenance" {
  description = "Scheduled maintenance configuration"
  type = object({
    enabled = bool
    day_of_week = string
    start_time = string
    duration_hours = number
    auto_apply_updates = bool
  })
  default = {
    enabled = true
    day_of_week = "Sunday"
    start_time = "02:00"
    duration_hours = 2
    auto_apply_updates = true
  }
}

# ====================================
# Feature Flags for Development
# ====================================

variable "feature_flags" {
  description = "Feature flags for development environment"
  type = map(bool)
  default = {
    "enable_new_ui" = true
    "enable_advanced_search" = true
    "enable_book_recommendations" = true
    "enable_social_features" = false
    "enable_mobile_app_api" = true
    "enable_analytics_dashboard" = false
    "enable_ai_features" = false
  }
}

# ====================================
# Custom Tags
# ====================================

variable "custom_tags" {
  description = "Custom tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "development"
    Purpose = "development"
    AutoShutdown = "enabled"
    CostOptimized = "true"
    BackupRequired = "false"
  }
}
