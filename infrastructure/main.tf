# ====================================
# Oracle Cloud Infrastructure (OCI) 
# Book Library System - Main Configuration
# ====================================

# Terraform Configuration
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }

  # Remote State Configuration
  backend "s3" {
    # Oracle Object Storage with S3 compatibility
    endpoint                    = var.object_storage_endpoint
    bucket                      = var.terraform_state_bucket
    key                         = "terraform/library-system/terraform.tfstate"
    region                      = var.region
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style           = true
  }
}

# ====================================
# Provider Configuration
# ====================================

provider "oci" {
  tenancy_ocid        = var.tenancy_ocid
  user_ocid          = var.user_ocid
  fingerprint        = var.fingerprint
  private_key_path   = var.private_key_path
  region             = var.region
}

provider "random" {}
provider "time" {}

# ====================================
# Local Values
# ====================================

locals {
  # Common tags for all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    CreatedBy   = "terraform"
    CreatedOn   = timestamp()
  }

  # Resource naming convention
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Availability Domains
  ad_count = length(data.oci_identity_availability_domains.ads.availability_domains)
  
  # Network CIDR blocks
  vcn_cidr               = var.vcn_cidr
  public_subnet_cidr     = cidrsubnet(var.vcn_cidr, 8, 1)
  private_subnet_cidr    = cidrsubnet(var.vcn_cidr, 8, 2)
  database_subnet_cidr   = cidrsubnet(var.vcn_cidr, 8, 3)
  analytics_subnet_cidr  = cidrsubnet(var.vcn_cidr, 8, 4)
}

# ====================================
# Data Sources
# ====================================

# Availability Domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Fault Domains
data "oci_identity_fault_domains" "fds" {
  count               = local.ad_count
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[count.index].name
  compartment_id      = var.compartment_ocid
}

# Oracle Linux Images
data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = var.compute_shape
  sort_by                  = "TIMECREATED"
  sort_order              = "DESC"
  
  filter {
    name   = "display_name"
    values = ["^.*Oracle-Linux-8.*-\\d{4}\\.\\d{2}\\.\\d{2}-\\d+$"]
    regex  = true
  }
}

# ====================================
# Random Values for Unique Resources
# ====================================

# Random suffix for globally unique names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Random password for database admin
resource "random_password" "db_admin_password" {
  length  = 16
  special = true
}

# Random password for application database user
resource "random_password" "app_db_password" {
  length  = 16
  special = true
}

# ====================================
# Core Infrastructure Modules
# ====================================

# Network Infrastructure Module
module "networking" {
  source = "./modules/networking"

  # General Configuration
  compartment_ocid = var.compartment_ocid
  project_name     = var.project_name
  environment      = var.environment
  common_tags      = local.common_tags

  # Network Configuration
  vcn_cidr               = local.vcn_cidr
  public_subnet_cidr     = local.public_subnet_cidr
  private_subnet_cidr    = local.private_subnet_cidr
  database_subnet_cidr   = local.database_subnet_cidr
  analytics_subnet_cidr  = local.analytics_subnet_cidr

  # DNS Configuration
  dns_label = var.dns_label
  
  # Security Configuration
  allowed_cidr_blocks = var.allowed_cidr_blocks
  ssh_public_key      = var.ssh_public_key
}

# Security Infrastructure Module
module "security" {
  source = "./modules/security"

  # General Configuration
  compartment_ocid = var.compartment_ocid
  tenancy_ocid     = var.tenancy_ocid
  project_name     = var.project_name
  environment      = var.environment
  common_tags      = local.common_tags

  # Network Dependencies
  vcn_id               = module.networking.vcn_id
  public_subnet_id     = module.networking.public_subnet_id
  private_subnet_id    = module.networking.private_subnet_id
  database_subnet_id   = module.networking.database_subnet_id

  # SSL Configuration
  ssl_certificate_name = var.ssl_certificate_name
  domain_name         = var.domain_name
}

# Database Infrastructure Module
module "database" {
  source = "./modules/database"

  # General Configuration
  compartment_ocid = var.compartment_ocid
  project_name     = var.project_name
  environment      = var.environment
  common_tags      = local.common_tags

  # Network Dependencies
  subnet_id = module.networking.database_subnet_id
  nsg_ids   = [module.security.database_nsg_id]

  # Database Configuration
  db_name             = var.db_name
  db_admin_password   = random_password.db_admin_password.result
  app_db_password     = random_password.app_db_password.result
  db_version          = var.db_version
  cpu_core_count      = var.db_cpu_core_count
  data_storage_size   = var.db_data_storage_size
  auto_scaling_enabled = var.db_auto_scaling_enabled

  # Backup Configuration
  backup_retention_days = var.backup_retention_days
}

# Compute Infrastructure Module
module "compute" {
  source = "./modules/compute"

  # General Configuration
  compartment_ocid = var.compartment_ocid
  project_name     = var.project_name
  environment      = var.environment
  common_tags      = local.common_tags

  # Network Dependencies
  vcn_id            = module.networking.vcn_id
  public_subnet_id  = module.networking.public_subnet_id
  private_subnet_id = module.networking.private_subnet_id
  lb_nsg_id        = module.security.load_balancer_nsg_id
  app_nsg_id       = module.security.application_nsg_id

  # Compute Configuration
  availability_domains = data.oci_identity_availability_domains.ads.availability_domains
  fault_domains       = data.oci_identity_fault_domains.fds
  compute_shape       = var.compute_shape
  compute_image_id    = data.oci_core_images.oracle_linux.images[0].id
  ssh_public_key      = var.ssh_public_key

  # Auto Scaling Configuration
  min_instances     = var.min_instances
  max_instances     = var.max_instances
  desired_instances = var.desired_instances

  # Load Balancer Configuration
  ssl_certificate_id = module.security.ssl_certificate_id
  domain_name       = var.domain_name

  # Application Configuration
  app_port = var.app_port
}

# Monitoring Infrastructure Module
module "monitoring" {
  source = "./modules/monitoring"

  # General Configuration
  compartment_ocid = var.compartment_ocid
  project_name     = var.project_name
  environment      = var.environment
  common_tags      = local.common_tags

  # Resource Dependencies
  compute_instances = module.compute.instance_ids
  load_balancer_id  = module.compute.load_balancer_id
  database_id       = module.database.autonomous_database_id
  
  # Notification Configuration
  notification_email = var.notification_email
  slack_webhook_url  = var.slack_webhook_url

  # Monitoring Configuration
  log_retention_days = var.log_retention_days
}

# ====================================
# Outputs
# ====================================

# Network Outputs
output "vcn_id" {
  description = "VCN OCID"
  value       = module.networking.vcn_id
}

output "public_subnet_id" {
  description = "Public subnet OCID"
  value       = module.networking.public_subnet_id
}

output "private_subnet_id" {
  description = "Private subnet OCID"
  value       = module.networking.private_subnet_id
}

output "database_subnet_id" {
  description = "Database subnet OCID"
  value       = module.networking.database_subnet_id
}

# Security Outputs
output "load_balancer_nsg_id" {
  description = "Load balancer NSG OCID"
  value       = module.security.load_balancer_nsg_id
}

output "application_nsg_id" {
  description = "Application NSG OCID"
  value       = module.security.application_nsg_id
}

output "database_nsg_id" {
  description = "Database NSG OCID"
  value       = module.security.database_nsg_id
}

# Database Outputs
output "autonomous_database_id" {
  description = "Autonomous Database OCID"
  value       = module.database.autonomous_database_id
}

output "database_connection_string" {
  description = "Database connection string"
  value       = module.database.connection_string
  sensitive   = true
}

output "database_wallet_content" {
  description = "Database wallet content"
  value       = module.database.wallet_content
  sensitive   = true
}

# Compute Outputs
output "load_balancer_public_ip" {
  description = "Load balancer public IP address"
  value       = module.compute.load_balancer_public_ip
}

output "load_balancer_id" {
  description = "Load balancer OCID"
  value       = module.compute.load_balancer_id
}

output "instance_pool_id" {
  description = "Instance pool OCID"
  value       = module.compute.instance_pool_id
}

output "auto_scaling_config_id" {
  description = "Auto scaling configuration OCID"
  value       = module.compute.auto_scaling_config_id
}

# Application Outputs
output "application_url" {
  description = "Application URL"
  value       = "https://${var.domain_name}"
}

output "application_health_check_url" {
  description = "Application health check URL"
  value       = "https://${var.domain_name}/health"
}

# Monitoring Outputs
output "log_group_id" {
  description = "Log group OCID"
  value       = module.monitoring.log_group_id
}

output "notification_topic_id" {
  description = "Notification topic OCID"
  value       = module.monitoring.notification_topic_id
}

# Resource Summary
output "resource_summary" {
  description = "Summary of created resources"
  value = {
    environment    = var.environment
    region        = var.region
    vcn_cidr      = local.vcn_cidr
    instance_count = "${var.min_instances}-${var.max_instances}"
    database_size = "${var.db_data_storage_size}GB"
    domain_name   = var.domain_name
    created_at    = timestamp()
  }
}
