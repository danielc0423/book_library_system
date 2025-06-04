# ====================================
# Security Module Variables
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# General Configuration Variables
# ====================================

variable "compartment_ocid" {
  description = "The OCID of the compartment where security resources will be created"
  type        = string
}

variable "tenancy_ocid" {
  description = "The OCID of the tenancy (required for IAM resources)"
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

variable "region" {
  description = "OCI region"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

# ====================================
# Network Dependencies
# ====================================

variable "vcn_id" {
  description = "The OCID of the VCN"
  type        = string
}

variable "public_subnet_id" {
  description = "The OCID of the public subnet"
  type        = string
}

variable "private_subnet_id" {
  description = "The OCID of the private subnet"
  type        = string
}

variable "database_subnet_id" {
  description = "The OCID of the database subnet"
  type        = string
}

# ====================================
# Security Configuration Variables
# ====================================

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the infrastructure"
  type        = list(string)
  default     = ["0.0.0.0/0"]
  
  validation {
    condition = alltrue([
      for cidr in var.allowed_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All allowed CIDR blocks must be valid IPv4 CIDR notation."
  }
}

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
# SSL Certificate Configuration
# ====================================

variable "ssl_certificate_name" {
  description = "Name for the SSL certificate"
  type        = string
  default     = "library-ssl-cert"
}

variable "domain_name" {
  description = "Domain name for SSL certificate"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*\\.[a-z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid FQDN."
  }
}

variable "ssl_certificate_validity_days" {
  description = "Validity period for SSL certificate in days"
  type        = number
  default     = 365
  
  validation {
    condition     = var.ssl_certificate_validity_days >= 1 && var.ssl_certificate_validity_days <= 3650
    error_message = "SSL certificate validity must be between 1 and 3650 days."
  }
}

# ====================================
# Encryption Configuration
# ====================================

variable "enable_encryption_at_rest" {
  description = "Enable encryption at rest using customer-managed keys"
  type        = bool
  default     = true
}

variable "key_algorithm" {
  description = "Encryption key algorithm"
  type        = string
  default     = "AES"
  
  validation {
    condition     = contains(["AES", "RSA", "ECDSA"], var.key_algorithm)
    error_message = "Key algorithm must be one of: AES, RSA, ECDSA."
  }
}

variable "key_length" {
  description = "Encryption key length"
  type        = number
  default     = 32
  
  validation {
    condition     = contains([16, 24, 32], var.key_length)
    error_message = "Key length must be 16, 24, or 32 for AES."
  }
}

# ====================================
# IAM Configuration
# ====================================

variable "create_iam_resources" {
  description = "Create IAM policies and groups"
  type        = bool
  default     = true
}

variable "database_admin_users" {
  description = "List of users to add to database admin group"
  type        = list(string)
  default     = []
}

variable "analytics_admin_users" {
  description = "List of users to add to analytics admin group"
  type        = list(string)
  default     = []
}

variable "application_admin_users" {
  description = "List of users to add to application admin group"
  type        = list(string)
  default     = []
}

# ====================================
# Network Security Group Configuration
# ====================================

variable "enable_network_security_groups" {
  description = "Enable Network Security Groups"
  type        = bool
  default     = true
}

variable "load_balancer_ports" {
  description = "Ports to allow on load balancer"
  type        = list(number)
  default     = [80, 443]
  
  validation {
    condition = alltrue([
      for port in var.load_balancer_ports : port >= 1 && port <= 65535
    ])
    error_message = "All ports must be between 1 and 65535."
  }
}

variable "application_ports" {
  description = "Ports to allow on application servers"
  type        = list(number)
  default     = [8000, 22]
  
  validation {
    condition = alltrue([
      for port in var.application_ports : port >= 1 && port <= 65535
    ])
    error_message = "All ports must be between 1 and 65535."
  }
}

variable "database_ports" {
  description = "Ports to allow on database"
  type        = list(number)
  default     = [1521, 1522]
  
  validation {
    condition = alltrue([
      for port in var.database_ports : port >= 1 && port <= 65535
    ])
    error_message = "All ports must be between 1 and 65535."
  }
}

variable "analytics_ports" {
  description = "Ports to allow on analytics services"
  type        = list(number)
  default     = [9502, 443]
  
  validation {
    condition = alltrue([
      for port in var.analytics_ports : port >= 1 && port <= 65535
    ])
    error_message = "All ports must be between 1 and 65535."
  }
}

# ====================================
# WAF Configuration
# ====================================

variable "waf_rate_limit_requests" {
  description = "Number of requests per minute before rate limiting"
  type        = number
  default     = 100
  
  validation {
    condition     = var.waf_rate_limit_requests >= 1 && var.waf_rate_limit_requests <= 10000
    error_message = "WAF rate limit must be between 1 and 10000 requests per minute."
  }
}

variable "waf_block_duration_seconds" {
  description = "Duration to block requests when rate limit is exceeded"
  type        = number
  default     = 60
  
  validation {
    condition     = var.waf_block_duration_seconds >= 1 && var.waf_block_duration_seconds <= 3600
    error_message = "WAF block duration must be between 1 and 3600 seconds."
  }
}

variable "waf_custom_rules" {
  description = "Custom WAF rules"
  type = list(object({
    name       = string
    condition  = string
    action     = string
  }))
  default = []
}

# ====================================
# Cloud Guard Configuration
# ====================================

variable "cloud_guard_target_type" {
  description = "Cloud Guard target type"
  type        = string
  default     = "COMPARTMENT"
  
  validation {
    condition     = contains(["COMPARTMENT", "TENANCY"], var.cloud_guard_target_type)
    error_message = "Cloud Guard target type must be COMPARTMENT or TENANCY."
  }
}

variable "cloud_guard_detector_recipes" {
  description = "List of Cloud Guard detector recipes to enable"
  type        = list(string)
  default     = []
}

variable "cloud_guard_responder_recipes" {
  description = "List of Cloud Guard responder recipes to enable"
  type        = list(string)
  default     = []
}

# ====================================
# Vulnerability Scanning Configuration
# ====================================

variable "vulnerability_scan_level" {
  description = "Vulnerability scanning level"
  type        = string
  default     = "STANDARD"
  
  validation {
    condition     = contains(["STANDARD", "LIGHT", "DEEP"], var.vulnerability_scan_level)
    error_message = "Vulnerability scan level must be STANDARD, LIGHT, or DEEP."
  }
}

variable "vulnerability_scan_schedule" {
  description = "Vulnerability scanning schedule (cron expression)"
  type        = string
  default     = "0 2 * * 0"  # Weekly on Sunday at 2 AM
}

variable "cis_benchmark_scan_level" {
  description = "CIS benchmark scanning level"
  type        = string
  default     = "STRICT"
  
  validation {
    condition     = contains(["STRICT", "MEDIUM", "LIGHT"], var.cis_benchmark_scan_level)
    error_message = "CIS benchmark scan level must be STRICT, MEDIUM, or LIGHT."
  }
}

# ====================================
# Vault Configuration
# ====================================

variable "vault_type" {
  description = "Type of vault to create"
  type        = string
  default     = "DEFAULT"
  
  validation {
    condition     = contains(["DEFAULT", "VIRTUAL_PRIVATE"], var.vault_type)
    error_message = "Vault type must be DEFAULT or VIRTUAL_PRIVATE."
  }
}

variable "vault_replica_region" {
  description = "Region for vault replica (for high availability)"
  type        = string
  default     = ""
}

variable "key_protection_mode" {
  description = "Key protection mode"
  type        = string
  default     = "SOFTWARE"
  
  validation {
    condition     = contains(["SOFTWARE", "HSM"], var.key_protection_mode)
    error_message = "Key protection mode must be SOFTWARE or HSM."
  }
}

# ====================================
# Security Monitoring Configuration
# ====================================

variable "enable_security_monitoring" {
  description = "Enable comprehensive security monitoring"
  type        = bool
  default     = true
}

variable "security_alert_email" {
  description = "Email address for security alerts"
  type        = string
  default     = ""
  
  validation {
    condition = var.security_alert_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.security_alert_email))
    error_message = "Security alert email must be a valid email address or empty."
  }
}

variable "enable_audit_logging" {
  description = "Enable audit logging for all security events"
  type        = bool
  default     = true
}

# ====================================
# Cost Optimization
# ====================================

variable "enable_cost_optimization" {
  description = "Enable cost optimization features"
  type        = bool
  default     = false
}

variable "vault_auto_backup" {
  description = "Enable automatic vault backup"
  type        = bool
  default     = true
}

# ====================================
# Advanced Security Features
# ====================================

variable "enable_data_safe" {
  description = "Enable Oracle Data Safe for database security"
  type        = bool
  default     = false
}

variable "enable_security_zones" {
  description = "Enable Security Zones for additional protection"
  type        = bool
  default     = false
}

variable "enable_bastion_service" {
  description = "Enable OCI Bastion service for secure access"
  type        = bool
  default     = true
}

# ====================================
# Compliance Configuration
# ====================================

variable "compliance_standards" {
  description = "List of compliance standards to adhere to"
  type        = list(string)
  default     = ["CIS", "PCI-DSS", "SOC2"]
}

variable "data_retention_days" {
  description = "Data retention period for security logs"
  type        = number
  default     = 90
  
  validation {
    condition     = var.data_retention_days >= 30 && var.data_retention_days <= 2555  # 7 years
    error_message = "Data retention must be between 30 days and 7 years."
  }
}

variable "enable_data_classification" {
  description = "Enable automatic data classification"
  type        = bool
  default     = true
}
