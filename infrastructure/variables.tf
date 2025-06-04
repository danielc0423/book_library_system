# ====================================
# Variable Definitions
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# OCI Authentication Variables
# ====================================

variable "tenancy_ocid" {
  description = "The OCID of the tenancy"
  type        = string
  sensitive   = true
}

variable "user_ocid" {
  description = "The OCID of the user calling the API"
  type        = string
  sensitive   = true
}

variable "fingerprint" {
  description = "The fingerprint of the public key to use for authentication"
  type        = string
  sensitive   = true
}

variable "private_key_path" {
  description = "The path to the private key to use for authentication"
  type        = string
  sensitive   = true
}

variable "compartment_ocid" {
  description = "The OCID of the compartment where resources will be created"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "The OCI region where resources will be created"
  type        = string
  default     = "us-ashburn-1"
  
  validation {
    condition = contains([
      "us-ashburn-1", "us-phoenix-1", "ca-toronto-1", "ca-montreal-1",
      "eu-frankfurt-1", "eu-zurich-1", "eu-amsterdam-1", "uk-london-1",
      "ap-mumbai-1", "ap-seoul-1", "ap-sydney-1", "ap-tokyo-1",
      "sa-saopaulo-1", "me-jeddah-1", "af-johannesburg-1"
    ], var.region)
    error_message = "Region must be a valid OCI region."
  }
}

# ====================================
# Project Configuration Variables
# ====================================

variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  default     = "library-system"
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.project_name))
    error_message = "Project name must start with a letter, contain only lowercase letters, numbers, and hyphens, and end with a letter or number."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "development", "staging", "stage", "prod", "production"], var.environment)
    error_message = "Environment must be one of: dev, development, staging, stage, prod, production."
  }
}

variable "owner" {
  description = "Owner of the resources (for tagging)"
  type        = string
  default     = "library-admin"
}

# ====================================
# Network Configuration Variables
# ====================================

variable "vcn_cidr" {
  description = "CIDR block for the VCN"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vcn_cidr, 0))
    error_message = "VCN CIDR must be a valid IPv4 CIDR block."
  }
}

variable "dns_label" {
  description = "DNS label for the VCN"
  type        = string
  default     = "librarysystem"
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9]*$", var.dns_label))
    error_message = "DNS label must start with a letter and contain only lowercase letters and numbers."
  }
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the infrastructure"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Should be restricted in production
  
  validation {
    condition = alltrue([
      for cidr in var.allowed_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All allowed CIDR blocks must be valid IPv4 CIDR notation."
  }
}

# ====================================
# Compute Configuration Variables
# ====================================

variable "compute_shape" {
  description = "Shape for compute instances"
  type        = string
  default     = "VM.Standard.E4.Flex"
  
  validation {
    condition = contains([
      "VM.Standard.E4.Flex", "VM.Standard.E3.Flex", "VM.Standard.A1.Flex",
      "VM.Standard3.Flex", "VM.Optimized3.Flex"
    ], var.compute_shape)
    error_message = "Compute shape must be a valid OCI shape."
  }
}

variable "compute_ocpus" {
  description = "Number of OCPUs for compute instances"
  type        = number
  default     = 2
  
  validation {
    condition     = var.compute_ocpus >= 1 && var.compute_ocpus <= 64
    error_message = "OCPU count must be between 1 and 64."
  }
}

variable "compute_memory_gb" {
  description = "Memory in GB for compute instances"
  type        = number
  default     = 16
  
  validation {
    condition     = var.compute_memory_gb >= 1 && var.compute_memory_gb <= 1024
    error_message = "Memory must be between 1 and 1024 GB."
  }
}

variable "boot_volume_size_gb" {
  description = "Boot volume size in GB"
  type        = number
  default     = 50
  
  validation {
    condition     = var.boot_volume_size_gb >= 50 && var.boot_volume_size_gb <= 32768
    error_message = "Boot volume size must be between 50 and 32768 GB."
  }
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
  sensitive   = true
}

# ====================================
# Auto Scaling Configuration Variables
# ====================================

variable "min_instances" {
  description = "Minimum number of instances in the auto scaling group"
  type        = number
  default     = 2
  
  validation {
    condition     = var.min_instances >= 1 && var.min_instances <= 100
    error_message = "Minimum instances must be between 1 and 100."
  }
}

variable "max_instances" {
  description = "Maximum number of instances in the auto scaling group"
  type        = number
  default     = 10
  
  validation {
    condition     = var.max_instances >= 1 && var.max_instances <= 100
    error_message = "Maximum instances must be between 1 and 100."
  }
}

variable "desired_instances" {
  description = "Desired number of instances in the auto scaling group"
  type        = number
  default     = 3
  
  validation {
    condition     = var.desired_instances >= 1 && var.desired_instances <= 100
    error_message = "Desired instances must be between 1 and 100."
  }
}

# ====================================
# Database Configuration Variables
# ====================================

variable "db_name" {
  description = "Name of the Autonomous Database"
  type        = string
  default     = "LibraryDB"
  
  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]*$", var.db_name))
    error_message = "Database name must start with a letter and contain only letters, numbers, and underscores."
  }
}

variable "db_version" {
  description = "Oracle Database version"
  type        = string
  default     = "21c"
  
  validation {
    condition     = contains(["19c", "21c", "23ai"], var.db_version)
    error_message = "Database version must be one of: 19c, 21c, 23ai."
  }
}

variable "db_cpu_core_count" {
  description = "Number of CPU cores for the database"
  type        = number
  default     = 2
  
  validation {
    condition     = var.db_cpu_core_count >= 1 && var.db_cpu_core_count <= 128
    error_message = "Database CPU core count must be between 1 and 128."
  }
}

variable "db_data_storage_size" {
  description = "Data storage size for the database in GB"
  type        = number
  default     = 1024
  
  validation {
    condition     = var.db_data_storage_size >= 20 && var.db_data_storage_size <= 393216
    error_message = "Database storage size must be between 20 and 393216 GB."
  }
}

variable "db_auto_scaling_enabled" {
  description = "Enable auto scaling for the database"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain database backups"
  type        = number
  default     = 30
  
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 60
    error_message = "Backup retention days must be between 1 and 60."
  }
}

# ====================================
# Application Configuration Variables
# ====================================

variable "app_port" {
  description = "Port on which the application runs"
  type        = number
  default     = 8000
  
  validation {
    condition     = var.app_port >= 1 && var.app_port <= 65535
    error_message = "Application port must be between 1 and 65535."
  }
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "library.example.com"
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*\\.[a-z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid FQDN."
  }
}

variable "ssl_certificate_name" {
  description = "Name for the SSL certificate"
  type        = string
  default     = "library-ssl-cert"
}

# ====================================
# Monitoring Configuration Variables
# ====================================

variable "notification_email" {
  description = "Email address for notifications"
  type        = string
  default     = "admin@library.com"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "Notification email must be a valid email address."
  }
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 90
  
  validation {
    condition     = var.log_retention_days >= 1 && var.log_retention_days <= 365
    error_message = "Log retention days must be between 1 and 365."
  }
}

# ====================================
# Terraform State Configuration Variables
# ====================================

variable "object_storage_endpoint" {
  description = "Object storage endpoint for Terraform state"
  type        = string
  default     = "https://objectstorage.us-ashburn-1.oraclecloud.com"
}

variable "terraform_state_bucket" {
  description = "Object storage bucket for Terraform state"
  type        = string
  default     = "terraform-state"
}

# ====================================
# Cost Optimization Variables
# ====================================

variable "enable_cost_optimization" {
  description = "Enable cost optimization features (spot instances, etc.)"
  type        = bool
  default     = false
}

variable "spot_instance_percentage" {
  description = "Percentage of instances to run as spot instances"
  type        = number
  default     = 50
  
  validation {
    condition     = var.spot_instance_percentage >= 0 && var.spot_instance_percentage <= 100
    error_message = "Spot instance percentage must be between 0 and 100."
  }
}

# ====================================
# High Availability Variables
# ====================================

variable "enable_multi_ad" {
  description = "Enable multi-availability domain deployment"
  type        = bool
  default     = true
}

variable "enable_cross_region_backup" {
  description = "Enable cross-region backup for disaster recovery"
  type        = bool
  default     = false
}

# ====================================
# Security Variables
# ====================================

variable "enable_waf" {
  description = "Enable Web Application Firewall"
  type        = bool
  default     = true
}

variable "enable_cloud_guard" {
  description = "Enable Cloud Guard security monitoring"
  type        = bool
  default     = true
}

variable "enable_vulnerability_scanning" {
  description = "Enable vulnerability scanning"
  type        = bool
  default     = true
}

# ====================================
# Analytics Configuration Variables
# ====================================

variable "analytics_shape" {
  description = "Shape for Oracle Analytics Cloud instance"
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "analytics_ocpus" {
  description = "Number of OCPUs for Analytics Cloud"
  type        = number
  default     = 4
}

variable "analytics_storage_gb" {
  description = "Storage size for Analytics Cloud in GB"
  type        = number
  default     = 1024
}

# ====================================
# Integration Cloud Variables
# ====================================

variable "oic_message_packs" {
  description = "Number of message packs for Oracle Integration Cloud"
  type        = number
  default     = 1
}

variable "oic_edition" {
  description = "Oracle Integration Cloud edition"
  type        = string
  default     = "STANDARD"
  
  validation {
    condition     = contains(["STANDARD", "ENTERPRISE"], var.oic_edition)
    error_message = "OIC edition must be either STANDARD or ENTERPRISE."
  }
}

# ====================================
# Development/Testing Variables
# ====================================

variable "enable_bastion_host" {
  description = "Enable bastion host for secure access"
  type        = bool
  default     = true
}

variable "bastion_shape" {
  description = "Shape for bastion host"
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "enable_development_tools" {
  description = "Enable development and debugging tools"
  type        = bool
  default     = false
}

# ====================================
# Tagging Variables
# ====================================

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "IT-Library"
}

variable "budget_alert_threshold" {
  description = "Budget alert threshold in USD"
  type        = number
  default     = 1000
}
