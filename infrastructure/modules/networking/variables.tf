# ====================================
# Networking Module Variables
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# General Configuration Variables
# ====================================

variable "compartment_ocid" {
  description = "The OCID of the compartment where networking resources will be created"
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

variable "vcn_cidr" {
  description = "CIDR block for the VCN"
  type        = string
  
  validation {
    condition     = can(cidrhost(var.vcn_cidr, 0))
    error_message = "VCN CIDR must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  
  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "Public subnet CIDR must be a valid IPv4 CIDR block."
  }
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  
  validation {
    condition     = can(cidrhost(var.private_subnet_cidr, 0))
    error_message = "Private subnet CIDR must be a valid IPv4 CIDR block."
  }
}

variable "database_subnet_cidr" {
  description = "CIDR block for the database subnet"
  type        = string
  
  validation {
    condition     = can(cidrhost(var.database_subnet_cidr, 0))
    error_message = "Database subnet CIDR must be a valid IPv4 CIDR block."
  }
}

variable "analytics_subnet_cidr" {
  description = "CIDR block for the analytics subnet"
  type        = string
  
  validation {
    condition     = can(cidrhost(var.analytics_subnet_cidr, 0))
    error_message = "Analytics subnet CIDR must be a valid IPv4 CIDR block."
  }
}

variable "dns_label" {
  description = "DNS label for the VCN"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9]*$", var.dns_label))
    error_message = "DNS label must start with a letter and contain only lowercase letters and numbers."
  }
}

# ====================================
# Security Configuration Variables
# ====================================

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the infrastructure"
  type        = list(string)
  
  validation {
    condition = alltrue([
      for cidr in var.allowed_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All allowed CIDR blocks must be valid IPv4 CIDR notation."
  }
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
  sensitive   = true
}

# ====================================
# Optional Configuration Variables
# ====================================

variable "enable_flow_logs" {
  description = "Enable VCN flow logs for monitoring"
  type        = bool
  default     = true
}

variable "log_group_id" {
  description = "Log group ID for VCN flow logs"
  type        = string
  default     = ""
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VCN"
  type        = bool
  default     = true
}

variable "enable_dns_resolution" {
  description = "Enable DNS resolution in the VCN"
  type        = bool
  default     = true
}

# ====================================
# Advanced Network Configuration
# ====================================

variable "enable_ipv6" {
  description = "Enable IPv6 support (if available in region)"
  type        = bool
  default     = false
}

variable "custom_dhcp_options" {
  description = "Custom DHCP options (optional)"
  type = object({
    domain_name_servers = list(string)
    search_domains     = list(string)
  })
  default = null
}

variable "additional_route_rules" {
  description = "Additional route rules for route tables"
  type = map(list(object({
    destination       = string
    destination_type  = string
    network_entity_id = string
  })))
  default = {}
}

# ====================================
# High Availability Configuration
# ====================================

variable "enable_multi_ad_subnets" {
  description = "Create subnets across multiple availability domains"
  type        = bool
  default     = false
}

variable "availability_domain_names" {
  description = "List of availability domain names for multi-AD deployment"
  type        = list(string)
  default     = []
}

# ====================================
# Network Monitoring Configuration
# ====================================

variable "enable_network_monitoring" {
  description = "Enable network monitoring and alerting"
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Number of days to retain flow logs"
  type        = number
  default     = 30
  
  validation {
    condition     = var.flow_log_retention_days >= 1 && var.flow_log_retention_days <= 365
    error_message = "Flow log retention days must be between 1 and 365."
  }
}

# ====================================
# Cost Optimization Configuration
# ====================================

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway (disable to save costs in dev environments)"
  type        = bool
  default     = true
}

variable "enable_service_gateway" {
  description = "Enable Service Gateway for Oracle Services Network"
  type        = bool
  default     = true
}

# ====================================
# Security Enhancement Variables
# ====================================

variable "enable_network_security_groups" {
  description = "Enable Network Security Groups for fine-grained security"
  type        = bool
  default     = true
}

variable "restrict_default_security_list" {
  description = "Remove default rules from default security list"
  type        = bool
  default     = true
}

variable "enable_ddos_protection" {
  description = "Enable DDoS protection (available in some regions)"
  type        = bool
  default     = false
}

# ====================================
# Custom Security Rules
# ====================================

variable "custom_ingress_rules" {
  description = "Custom ingress security rules"
  type = map(list(object({
    protocol    = string
    source      = string
    source_type = string
    port_min    = number
    port_max    = number
    description = string
  })))
  default = {}
}

variable "custom_egress_rules" {
  description = "Custom egress security rules"
  type = map(list(object({
    protocol         = string
    destination      = string
    destination_type = string
    port_min         = number
    port_max         = number
    description      = string
  })))
  default = {}
}

# ====================================
# Peering Configuration
# ====================================

variable "enable_local_peering" {
  description = "Enable local VCN peering"
  type        = bool
  default     = false
}

variable "local_peering_gateways" {
  description = "Configuration for local peering gateways"
  type = map(object({
    peer_vcn_id      = string
    peer_region      = string
    display_name     = string
    route_table_id   = string
  }))
  default = {}
}

variable "enable_remote_peering" {
  description = "Enable remote VCN peering"
  type        = bool
  default     = false
}

variable "remote_peering_connections" {
  description = "Configuration for remote peering connections"
  type = map(object({
    peer_region      = string
    peer_tenancy_id  = string
    peer_vcn_id      = string
    display_name     = string
  }))
  default = {}
}
