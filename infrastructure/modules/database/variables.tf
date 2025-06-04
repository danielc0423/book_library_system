# ====================================
# Database Module Variables
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# General Configuration Variables
# ====================================

variable "compartment_ocid" {
  description = "The OCID of the compartment where database resources will be created"
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
# Network Configuration Variables
# ====================================

variable "subnet_id" {
  description = "The OCID of the subnet where the database will be placed"
  type        = string
}

variable "nsg_ids" {
  description = "List of Network Security Group OCIDs to associate with the database"
  type        = list(string)
  default     = []
}

# ====================================
# Database Configuration Variables
# ====================================

variable "db_name" {
  description = "The database name"
  type        = string
  
  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]*$", var.db_name))
    error_message = "Database name must start with a letter and contain only letters, numbers, and underscores."
  }
}

variable "db_version" {
  description = "The Oracle Database version"
  type        = string
  default     = "21c"
  
  validation {
    condition     = contains(["19c", "21c", "23ai"], var.db_version)
    error_message = "Database version must be one of: 19c, 21c, 23ai."
  }
}

variable "db_workload" {
  description = "Autonomous Database workload type"
  type        = string
  default     = "OLTP"
  
  validation {
    condition     = contains(["OLTP", "DW", "AJD", "APEX"], var.db_workload)
    error_message = "Database workload must be one of: OLTP, DW, AJD, APEX."
  }
}

variable "cpu_core_count" {
  description = "The number of OCPU cores to enable"
  type        = number
  default     = 2
  
  validation {
    condition     = var.cpu_core_count >= 1 && var.cpu_core_count <= 128
    error_message = "CPU core count must be between 1 and 128."
  }
}

variable "data_storage_size" {
  description = "The size, in gigabytes, of the data volume that will be created and attached to the database"
  type        = number
  default     = 1024
  
  validation {
    condition     = var.data_storage_size >= 20 && var.data_storage_size <= 393216
    error_message = "Data storage size must be between 20 and 393216 GB."
  }
}

variable "auto_scaling_enabled" {
  description = "Indicates if auto scaling is enabled for the Autonomous Database OCPU core count"
  type        = bool
  default     = true
}

variable "license_model" {
  description = "The Oracle license model that applies to the Oracle Autonomous Database"
  type        = string
  default     = "LICENSE_INCLUDED"
  
  validation {
    condition     = contains(["LICENSE_INCLUDED", "BRING_YOUR_OWN_LICENSE"], var.license_model)
    error_message = "License model must be either LICENSE_INCLUDED or BRING_YOUR_OWN_LICENSE."
  }
}

# ====================================
# Security Configuration Variables
# ====================================

variable "db_admin_password" {
  description = "The password must be between 12 and 30 characters long, and must contain at least 1 uppercase, 1 lowercase, and 1 numeric character"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.db_admin_password) >= 12 && length(var.db_admin_password) <= 30
    error_message = "Admin password must be between 12 and 30 characters long."
  }
}

variable "app_db_username" {
  description = "Username for the application database user"
  type        = string
  default     = "APP_USER"
  
  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]*$", var.app_db_username))
    error_message = "App username must start with a letter and contain only letters, numbers, and underscores."
  }
}

variable "app_db_password" {
  description = "Password for the application database user"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.app_db_password) >= 12 && length(var.app_db_password) <= 30
    error_message = "App password must be between 12 and 30 characters long."
  }
}

variable "wallet_password" {
  description = "The password to encrypt the keys inside the wallet"
  type        = string
  default     = ""
  sensitive   = true
}

# ====================================
# Vault Integration Variables
# ====================================

variable "vault_id" {
  description = "The OCID of the vault to store database secrets"
  type        = string
  default     = ""
}

variable "vault_key_id" {
  description = "The OCID of the vault key for encrypting secrets"
  type        = string
  default     = ""
}

# ====================================
# Backup Configuration Variables
# ====================================

variable "backup_retention_days" {
  description = "Number of days to retain automatic backups"
  type        = number
  default     = 30
  
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 60
    error_message = "Backup retention days must be between 1 and 60."
  }
}

variable "enable_manual_backups" {
  description = "Enable manual backup creation"
  type        = bool
  default     = true
}

variable "enable_cross_region_backup" {
  description = "Enable cross-region backup for disaster recovery"
  type        = bool
  default     = false
}

variable "backup_schedule" {
  description = "Backup schedule in cron format"
  type        = string
  default     = "0 2 * * 0"  # Weekly on Sunday at 2 AM
}

# ====================================
# Monitoring Configuration Variables
# ====================================

variable "enable_monitoring" {
  description = "Enable database monitoring and alerting"
  type        = bool
  default     = true
}

variable "notification_topic_id" {
  description = "OCID of the notification topic for alerts"
  type        = string
  default     = ""
}

variable "cpu_utilization_threshold" {
  description = "CPU utilization threshold for alerts (percentage)"
  type        = number
  default     = 80
  
  validation {
    condition     = var.cpu_utilization_threshold >= 1 && var.cpu_utilization_threshold <= 100
    error_message = "CPU utilization threshold must be between 1 and 100."
  }
}

variable "storage_utilization_threshold" {
  description = "Storage utilization threshold for alerts (percentage)"
  type        = number
  default     = 85
  
  validation {
    condition     = var.storage_utilization_threshold >= 1 && var.storage_utilization_threshold <= 100
    error_message = "Storage utilization threshold must be between 1 and 100."
  }
}

variable "max_session_threshold" {
  description = "Maximum number of sessions threshold for alerts"
  type        = number
  default     = 100
  
  validation {
    condition     = var.max_session_threshold >= 1 && var.max_session_threshold <= 1000
    error_message = "Max session threshold must be between 1 and 1000."
  }
}

# ====================================
# Performance Configuration Variables
# ====================================

variable "connection_pool_initial_size" {
  description = "Initial connection pool size"
  type        = number
  default     = 5
  
  validation {
    condition     = var.connection_pool_initial_size >= 1 && var.connection_pool_initial_size <= 100
    error_message = "Initial pool size must be between 1 and 100."
  }
}

variable "connection_pool_max_size" {
  description = "Maximum connection pool size"
  type        = number
  default     = 20
  
  validation {
    condition     = var.connection_pool_max_size >= 1 && var.connection_pool_max_size <= 1000
    error_message = "Max pool size must be between 1 and 1000."
  }
}

variable "connection_pool_min_size" {
  description = "Minimum connection pool size"
  type        = number
  default     = 2
  
  validation {
    condition     = var.connection_pool_min_size >= 1 && var.connection_pool_min_size <= 100
    error_message = "Min pool size must be between 1 and 100."
  }
}

variable "connection_pool_increment" {
  description = "Connection pool increment size"
  type        = number
  default     = 2
  
  validation {
    condition     = var.connection_pool_increment >= 1 && var.connection_pool_increment <= 10
    error_message = "Pool increment must be between 1 and 10."
  }
}

variable "connection_timeout_seconds" {
  description = "Connection timeout in seconds"
  type        = number
  default     = 30
  
  validation {
    condition     = var.connection_timeout_seconds >= 5 && var.connection_timeout_seconds <= 300
    error_message = "Connection timeout must be between 5 and 300 seconds."
  }
}

# ====================================
# Advanced Features Variables
# ====================================

variable "enable_database_management" {
  description = "Enable Oracle Database Management for performance insights"
  type        = bool
  default     = true
}

variable "enable_apex" {
  description = "Enable Oracle APEX for the database"
  type        = bool
  default     = false
}

variable "enable_ords" {
  description = "Enable Oracle REST Data Services"
  type        = bool
  default     = true
}

variable "enable_machine_learning" {
  description = "Enable Oracle Machine Learning"
  type        = bool
  default     = true
}

variable "enable_graph" {
  description = "Enable Oracle Graph"
  type        = bool
  default     = false
}

# ====================================
# Operational Configuration Variables
# ====================================

variable "maintenance_window_preference" {
  description = "Maintenance window preference"
  type        = string
  default     = "NO_PREFERENCE"
  
  validation {
    condition     = contains(["NO_PREFERENCE", "EARLY_UPGRADE_ENABLED", "EARLY_UPGRADE_DISABLED"], var.maintenance_window_preference)
    error_message = "Maintenance window preference must be NO_PREFERENCE, EARLY_UPGRADE_ENABLED, or EARLY_UPGRADE_DISABLED."
  }
}

variable "create_connection_config" {
  description = "Create local connection configuration files"
  type        = bool
  default     = true
}

variable "run_init_scripts" {
  description = "Run database initialization scripts"
  type        = bool
  default     = true
}

variable "enable_audit_logging" {
  description = "Enable database audit logging"
  type        = bool
  default     = true
}

# ====================================
# Cost Optimization Variables
# ====================================

variable "enable_cost_optimization" {
  description = "Enable cost optimization features"
  type        = bool
  default     = false
}

variable "stop_db_on_weekends" {
  description = "Automatically stop database on weekends (dev environments only)"
  type        = bool
  default     = false
}

variable "auto_start_stop_schedule" {
  description = "Schedule for automatic start/stop (cron format)"
  type = object({
    start_time = string
    stop_time  = string
    timezone   = string
  })
  default = {
    start_time = "0 8 * * 1-5"   # 8 AM weekdays
    stop_time  = "0 18 * * 1-5"  # 6 PM weekdays
    timezone   = "UTC"
  }
}

# ====================================
# Development and Testing Variables
# ====================================

variable "enable_development_features" {
  description = "Enable development and testing features"
  type        = bool
  default     = false
}

variable "create_sample_data" {
  description = "Create sample data for testing"
  type        = bool
  default     = false
}

variable "enable_sql_developer_web" {
  description = "Enable SQL Developer Web"
  type        = bool
  default     = true
}

# ====================================
# High Availability Variables
# ====================================

variable "enable_disaster_recovery" {
  description = "Enable disaster recovery features"
  type        = bool
  default     = false
}

variable "standby_region" {
  description = "Region for disaster recovery standby database"
  type        = string
  default     = ""
}

variable "data_guard_type" {
  description = "Data Guard configuration type"
  type        = string
  default     = "ASYNC"
  
  validation {
    condition     = contains(["SYNC", "ASYNC", "FASTSYNC"], var.data_guard_type)
    error_message = "Data Guard type must be SYNC, ASYNC, or FASTSYNC."
  }
}

# ====================================
# Integration Variables
# ====================================

variable "enable_oac_integration" {
  description = "Enable Oracle Analytics Cloud integration"
  type        = bool
  default     = true
}

variable "enable_oic_integration" {
  description = "Enable Oracle Integration Cloud integration"
  type        = bool
  default     = true
}

variable "enable_oci_logging_integration" {
  description = "Enable OCI Logging integration"
  type        = bool
  default     = true
}

# ====================================
# Character Set and Localization
# ====================================

variable "character_set" {
  description = "Database character set"
  type        = string
  default     = "AL32UTF8"
  
  validation {
    condition     = contains(["AL32UTF8", "UTF8", "WE8ISO8859P1"], var.character_set)
    error_message = "Character set must be AL32UTF8, UTF8, or WE8ISO8859P1."
  }
}

variable "national_character_set" {
  description = "Database national character set"
  type        = string
  default     = "AL16UTF16"
  
  validation {
    condition     = contains(["AL16UTF16", "UTF8"], var.national_character_set)
    error_message = "National character set must be AL16UTF16 or UTF8."
  }
}

variable "database_timezone" {
  description = "Database timezone"
  type        = string
  default     = "UTC"
}
