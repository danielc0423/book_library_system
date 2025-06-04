# ====================================
# Development Environment Configuration
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# Core Configuration
# ====================================

terraform {
  required_version = ">= 1.5"
  
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }

  # Remote State Configuration for Development
  backend "s3" {
    bucket                      = "library-system-terraform-state-dev"
    key                         = "development/terraform.tfstate"
    region                      = "us-ashburn-1"
    endpoint                    = "https://<namespace>.compat.objectstorage.us-ashburn-1.oraclecloud.com"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    force_path_style            = true
  }
}

# ====================================
# Provider Configuration
# ====================================

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

provider "random" {}
provider "time" {}

# ====================================
# Local Values for Development
# ====================================

locals {
  environment = "development"
  project_name = "library-system"
  
  # Development-specific settings
  dev_settings = {
    # Cost optimization for development
    min_instances = 1
    max_instances = 3
    desired_instances = 1
    
    # Smaller compute shapes for cost savings
    compute_shape = "VM.Standard.E4.Flex"
    compute_ocpus = 1
    compute_memory_gb = 8
    
    # Reduced monitoring for development
    enable_detailed_monitoring = false
    enable_apm = false
    log_retention_days = 7
    
    # Development features
    enable_bastion_host = true
    enable_development_features = true
    install_development_tools = true
    enable_remote_debugging = true
    
    # Relaxed security for development access
    health_check_interval_seconds = 60
    auto_scaling_cooldown_seconds = 180
  }
  
  # Common tags for all development resources
  common_tags = {
    Environment = local.environment
    Project = local.project_name
    Owner = "Development Team"
    CostCenter = "Engineering"
    Terraform = "true"
    CreatedBy = "terraform"
    ManagedBy = "library-system-terraform"
  }
}

# ====================================
# Data Sources
# ====================================

# Get current availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

# Get fault domains
data "oci_identity_fault_domains" "fd" {
  count = length(data.oci_identity_availability_domains.ads.availability_domains)
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[count.index].name
  compartment_id = var.compartment_ocid
}

# ====================================
# Module Calls
# ====================================

# Networking Module
module "networking" {
  source = "../modules/networking"
  
  # Core configuration
  compartment_ocid = var.compartment_ocid
  project_name = local.project_name
  environment = local.environment
  common_tags = local.common_tags
  
  # VCN Configuration - smaller CIDR for development
  vcn_cidr_block = "10.0.0.0/16"
  vcn_dns_label = "libdevvcn"
  
  # Subnet Configuration
  public_subnet_cidr = "10.0.1.0/24"
  private_subnet_cidr = "10.0.2.0/24"
  database_subnet_cidr = "10.0.3.0/24"
  analytics_subnet_cidr = "10.0.4.0/24"
  
  # Development-specific network settings
  enable_nat_gateway = true
  enable_service_gateway = true
  enable_drg = false  # No DRG for development
  enable_vcn_flow_logs = false  # Disable for cost savings
  
  # Security settings - more permissive for development
  allow_ssh_from_internet = true
  ssh_allowed_cidrs = ["0.0.0.0/0"]  # Allow SSH from anywhere in dev
  
  # Availability configuration
  availability_domains = data.oci_identity_availability_domains.ads.availability_domains
}

# Security Module
module "security" {
  source = "../modules/security"
  
  # Core configuration
  compartment_ocid = var.compartment_ocid
  project_name = local.project_name
  environment = local.environment
  common_tags = local.common_tags
  
  # Network dependencies
  vcn_id = module.networking.vcn_id
  public_subnet_id = module.networking.public_subnet_id
  private_subnet_id = module.networking.private_subnet_id
  database_subnet_id = module.networking.database_subnet_id
  
  # Development security settings
  enable_waf = false  # Disable WAF for development
  enable_cloud_guard = false  # Disable for development
  enable_vulnerability_scanning = false  # Disable for cost savings
  
  # Certificate configuration - use self-signed for development
  enable_ssl_certificate = false
  domain_name = "dev.library.local"
  
  # IAM configuration
  enable_instance_principal = true
  enable_dynamic_groups = true
  
  # Vault configuration - use free tier
  vault_type = "DEFAULT"
  enable_vault_backup = false
}

# Database Module
module "database" {
  source = "../modules/database"
  
  # Core configuration
  compartment_ocid = var.compartment_ocid
  project_name = local.project_name
  environment = local.environment
  common_tags = local.common_tags
  
  # Network dependencies
  subnet_id = module.networking.database_subnet_id
  nsg_ids = [module.security.database_nsg_id]
  
  # Development database settings
  db_name = "libdevdb"
  db_workload = "OLTP"
  
  # Use Always Free tier for development
  is_free_tier = true
  cpu_core_count = 1
  data_storage_size_in_tbs = 0.02  # 20 GB for development
  
  # Backup configuration - minimal for development
  backup_retention_period_in_days = 7
  enable_automatic_backup = true
  
  # Development-specific settings
  is_auto_scaling_enabled = false
  auto_scaling_max_cpu_core_count = 1
  
  # Network access - allow from private subnet
  whitelisted_ips = [module.networking.private_subnet_cidr]
  
  # Admin credentials
  admin_password = var.db_admin_password
}

# Compute Module
module "compute" {
  source = "../modules/compute"
  
  # Core configuration
  compartment_ocid = var.compartment_ocid
  project_name = local.project_name
  environment = local.environment
  common_tags = local.common_tags
  
  # Network dependencies
  vcn_id = module.networking.vcn_id
  public_subnet_id = module.networking.public_subnet_id
  private_subnet_id = module.networking.private_subnet_id
  lb_nsg_id = module.security.load_balancer_nsg_id
  app_nsg_id = module.security.application_nsg_id
  bastion_nsg_ids = [module.security.bastion_nsg_id]
  
  # Development compute configuration
  compute_shape = local.dev_settings.compute_shape
  compute_ocpus = local.dev_settings.compute_ocpus
  compute_memory_gb = local.dev_settings.compute_memory_gb
  
  # Auto scaling - minimal for development
  min_instances = local.dev_settings.min_instances
  max_instances = local.dev_settings.max_instances
  desired_instances = local.dev_settings.desired_instances
  auto_scaling_cooldown_seconds = local.dev_settings.auto_scaling_cooldown_seconds
  
  # Load balancer configuration
  enable_load_balancer = true
  load_balancer_shape = "10Mbps"  # Minimal for development
  ssl_certificate_id = ""  # No SSL for development
  
  # Application configuration
  app_port = 8000
  health_check_path = "/health/"
  health_check_interval_ms = 60000  # Longer interval for development
  domain_name = "dev.library.local"
  
  # High availability configuration
  availability_domains = data.oci_identity_availability_domains.ads.availability_domains
  fault_domains = data.oci_identity_fault_domains.fd[*].fault_domains
  
  # Development features
  enable_bastion_host = local.dev_settings.enable_bastion_host
  bastion_shape = "VM.Standard.E4.Flex"
  bastion_ocpus = 1
  bastion_memory_gb = 4
  
  # Storage configuration - minimal for development
  create_app_data_volume = false
  
  # SSH access
  ssh_public_key = var.ssh_public_key
  
  # Development and debugging
  enable_development_features = local.dev_settings.enable_development_features
  install_development_tools = local.dev_settings.install_development_tools
  enable_remote_debugging = local.dev_settings.enable_remote_debugging
  
  # Cost optimization
  use_spot_instances = false  # Keep predictable for development
}

# Monitoring Module
module "monitoring" {
  source = "../modules/monitoring"
  
  # Core configuration
  compartment_ocid = var.compartment_ocid
  project_name = local.project_name
  environment = local.environment
  common_tags = local.common_tags
  
  # Resource dependencies
  vcn_id = module.networking.vcn_id
  load_balancer_id = module.compute.load_balancer_id
  load_balancer_ip = module.compute.load_balancer_ip
  instance_pool_id = module.compute.instance_pool_id
  database_id = module.database.database_id
  notification_topic_id = module.security.notification_topic_id
  object_storage_namespace = var.object_storage_namespace
  
  # Development monitoring settings
  enable_log_analytics = false  # Disable for cost savings
  enable_monitoring_alarms = true
  enable_apm = local.dev_settings.enable_apm
  
  # Reduced retention for development
  log_retention_days = local.dev_settings.log_retention_days
  audit_log_retention_days = 30
  enable_log_archival = false
  
  # Health check configuration
  health_check_interval_seconds = local.dev_settings.health_check_interval_seconds
  health_check_timeout_seconds = 15
  health_check_protocol = "HTTP"  # HTTP for development
  health_check_path = "/health/"
  health_check_port = 80
  
  # Dashboard configuration
  create_dashboards = true
  
  # Alarm thresholds - relaxed for development
  cpu_alarm_threshold = 90
  memory_alarm_threshold = 95
  response_time_threshold_ms = 10000
  api_error_rate_threshold = 10
  
  # Security monitoring - basic for development
  enable_security_monitoring = false
  enable_compliance_monitoring = false
  
  # Cost monitoring
  enable_cost_monitoring = true
  monthly_budget_threshold = 500  # Low budget for development
  cost_alert_percentage = 80
}

# ====================================
# Output Values
# ====================================

output "development_infrastructure" {
  description = "Development environment infrastructure details"
  value = {
    # Network Information
    vcn_id = module.networking.vcn_id
    public_subnet_id = module.networking.public_subnet_id
    private_subnet_id = module.networking.private_subnet_id
    database_subnet_id = module.networking.database_subnet_id
    
    # Compute Information
    load_balancer_ip = module.compute.load_balancer_ip
    bastion_public_ip = module.compute.bastion_public_ip
    instance_pool_id = module.compute.instance_pool_id
    
    # Database Information
    database_id = module.database.database_id
    database_connection_string = module.database.connection_string
    
    # Security Information
    ssl_certificate_id = module.security.ssl_certificate_id
    
    # Monitoring Information
    monitoring_alarms = module.monitoring.monitoring_alarms
    dashboards = module.monitoring.dashboards
    
    # Development-specific Information
    environment = local.environment
    project_name = local.project_name
    bastion_ssh_command = "ssh -i ~/.ssh/id_rsa opc@${module.compute.bastion_public_ip}"
    application_url = "http://${module.compute.load_balancer_ip}"
    development_features_enabled = local.dev_settings.enable_development_features
  }
}

output "development_access_information" {
  description = "Access information for development environment"
  value = {
    application_endpoints = {
      web_app = "http://${module.compute.load_balancer_ip}"
      api = "http://${module.compute.load_balancer_ip}/api/v1/"
      admin = "http://${module.compute.load_balancer_ip}/admin/"
      health_check = "http://${module.compute.load_balancer_ip}/health/"
    }
    
    ssh_access = {
      bastion_host = "ssh -i ~/.ssh/id_rsa opc@${module.compute.bastion_public_ip}"
      tunnel_to_app = "ssh -L 8080:${module.compute.load_balancer_ip}:80 -i ~/.ssh/id_rsa opc@${module.compute.bastion_public_ip}"
    }
    
    monitoring_urls = {
      oci_console = "https://cloud.oracle.com"
      monitoring = "https://cloud.oracle.com/monitoring/alarms?compartmentId=${var.compartment_ocid}"
      logging = "https://cloud.oracle.com/logging/logs?compartmentId=${var.compartment_ocid}"
    }
    
    development_tools = {
      remote_debugging_enabled = local.dev_settings.enable_remote_debugging
      development_tools_installed = local.dev_settings.install_development_tools
      bastion_access_required = local.dev_settings.enable_bastion_host
    }
  }
  sensitive = false
}

# ====================================
# Development Environment Status
# ====================================

output "development_status" {
  description = "Development environment deployment status"
  value = {
    environment = local.environment
    deployment_timestamp = timestamp()
    terraform_workspace = terraform.workspace
    
    infrastructure_status = {
      networking_deployed = true
      security_configured = true
      database_ready = true
      compute_running = true
      monitoring_active = true
    }
    
    cost_optimization = {
      free_tier_database = module.database.is_free_tier
      minimal_compute_shape = local.dev_settings.compute_shape
      reduced_monitoring = !local.dev_settings.enable_apm
      spot_instances = false
    }
    
    development_features = {
      bastion_host = local.dev_settings.enable_bastion_host
      development_tools = local.dev_settings.install_development_tools
      remote_debugging = local.dev_settings.enable_remote_debugging
      relaxed_security = true
    }
  }
}
