# ====================================
# Production Environment Variables
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
  description = "Primary OCI region for production"
  type        = string
  default     = "us-ashburn-1"
}

variable "backup_region" {
  description = "Secondary OCI region for backup and disaster recovery"
  type        = string
  default     = "us-phoenix-1"
}

variable "compartment_ocid" {
  description = "OCID of the compartment"
  type        = string
}

# ====================================
# Production Environment Configuration
# ====================================

variable "environment_name" {
  description = "Name of the environment"
  type        = string
  default     = "production"
  
  validation {
    condition     = var.environment_name == "production"
    error_message = "This configuration is specifically for production environment."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "library-system"
}

variable "business_unit" {
  description = "Business unit owning this production environment"
  type        = string
  default     = "Digital Services"
}

variable "cost_center" {
  description = "Cost center for billing and tagging"
  type        = string
  default     = "Production Operations"
}

variable "owner_email" {
  description = "Email of the production environment owner"
  type        = string
  default     = "production-ops@company.com"
}

# ====================================
# Domain and SSL Configuration
# ====================================

variable "production_domain_name" {
  description = "Primary domain name for production environment"
  type        = string
}

variable "enable_multi_region" {
  description = "Enable multi-region deployment"
  type        = bool
  default     = false
}

variable "enable_fastconnect" {
  description = "Enable Oracle FastConnect for dedicated connectivity"
  type        = bool
  default     = false
}

variable "fastconnect_provider" {
  description = "FastConnect provider configuration"
  type        = string
  default     = ""
}

variable "enable_hybrid_connectivity" {
  description = "Enable hybrid connectivity (DRG, FastConnect)"
  type        = bool
  default     = false
}

# ====================================
# Database Configuration
# ====================================

variable "db_admin_password" {
  description = "Admin password for the production database"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.db_admin_password) >= 16
    error_message = "Database admin password must be at least 16 characters long for production."
  }
}

variable "db_name" {
  description = "Name of the production database"
  type        = string
  default     = "libproddb"
}

variable "db_cpu_core_count" {
  description = "Number of CPU cores for production database"
  type        = number
  default     = 4
}

variable "db_max_cpu_core_count" {
  description = "Maximum number of CPU cores for auto-scaling"
  type        = number
  default     = 16
}

variable "db_storage_size_tb" {
  description = "Database storage size in terabytes"
  type        = number
  default     = 2
}

variable "enable_cross_region_dr" {
  description = "Enable cross-region disaster recovery with Data Guard"
  type        = bool
  default     = true
}

variable "db_maintenance_window" {
  description = "Database maintenance window configuration"
  type = object({
    day_of_week = string
    start_hour  = number
    duration_hours = number
  })
  default = {
    day_of_week = "SUNDAY"
    start_hour  = 2
    duration_hours = 4
  }
}

# ====================================
# Compute Configuration
# ====================================

variable "app_storage_size_gb" {
  description = "Application data storage size in GB"
  type        = number
  default     = 500
}

variable "ssh_public_key" {
  description = "SSH public key for emergency access"
  type        = string
  sensitive   = true
}

# ====================================
# Monitoring Configuration
# ====================================

variable "synthetic_monitor_locations" {
  description = "List of synthetic monitoring locations"
  type        = list(string)
  default = [
    "aws-us-east-1",
    "aws-us-west-2",
    "aws-eu-west-1",
    "gcp-us-central1",
    "azure-eastus"
  ]
}

variable "enable_external_monitoring" {
  description = "Enable integration with external monitoring systems"
  type        = bool
  default     = true
}

variable "external_monitoring_endpoints" {
  description = "External monitoring system endpoints"
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
# Security Configuration
# ====================================

variable "compliance_frameworks" {
  description = "List of compliance frameworks to enforce"
  type        = list(string)
  default     = ["SOX", "PCI-DSS", "GDPR", "SOC2", "ISO27001"]
}

# ====================================
# Cost Management
# ====================================

variable "production_budget_limit" {
  description = "Monthly budget limit for production environment (USD)"
  type        = number
  default     = 10000
}

# ====================================
# Object Storage Configuration
# ====================================

variable "object_storage_namespace" {
  description = "Object storage namespace"
  type        = string
}

# ====================================
# Custom Tags
# ====================================

variable "custom_tags" {
  description = "Custom tags to apply to all production resources"
  type        = map(string)
  default = {
    Environment = "production"
    Purpose = "production-workload"
    DataClass = "confidential"
    Criticality = "high"
    Compliance = "sox,pci-dss,gdpr"
    BackupRequired = "true"
    MonitoringLevel = "comprehensive"
    SecurityTier = "maximum"
    AvailabilityTier = "high"
    PerformanceTier = "premium"
  }
}
