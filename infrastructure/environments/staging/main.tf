# ====================================
# Staging Environment Configuration
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

  # Remote State Configuration for Staging
  backend "s3" {
    bucket                      = "library-system-terraform-state-staging"
    key                         = "staging/terraform.tfstate"
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
# Local Values for Staging
# ====================================

locals {
  environment = "staging"
  project_name = "library-system"
  
  # Staging-specific settings
  staging_settings = {
    # Production-like scaling for staging
    min_instances = 2
    max_instances = 6
    desired_instances = 2
    
    # Production-similar compute shapes
    compute_shape = "VM.Standard.E4.Flex"
    compute_ocpus = 2
    compute_memory_gb = 16
    
    # Enhanced monitoring for staging
    enable_detailed_monitoring = true
    enable_apm = true
    log_retention_days = 30
    
    # Security features for staging
    enable_bastion_host = true
    enable_ssl_certificates = true
    enable_waf = true
    
    # Performance tuning
    health_check_interval_seconds = 30
    auto_scaling_cooldown_seconds = 300
  }
  
  # Common tags for all staging resources
  common_tags = {
    Environment = local.environment
    Project = local.project_name
    Owner = "QA Team"
    CostCenter = "Engineering"
    Terraform = "true"
    CreatedBy = "terraform"
    ManagedBy = "library-system-terraform"
    Purpose = "staging"
    Criticality = "medium"
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
  
  # VCN Configuration - production-like for staging
  vcn_cidr_block = "10.1.0.0/16"
  vcn_dns_label = "libstagevcn"
  
  # Subnet Configuration
  public_subnet_cidr = "10.1.1.0/24"
  private_subnet_cidr = "10.1.2.0/24"
  database_subnet_cidr = "10.1.3.0/24"
  analytics_subnet_cidr = "10.1.4.0/24"
  
  # Staging-specific network settings
  enable_nat_gateway = true
  enable_service_gateway = true
  enable_drg = false  # No DRG for staging
  enable_vcn_flow_logs = true  # Enable for staging validation
  
  # Security settings - production-like but slightly relaxed
  allow_ssh_from_internet = false  # Only through bastion
  ssh_allowed_cidrs = var.allowed_ssh_cidrs
  
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
  
  # Staging security settings
  enable_waf = local.staging_settings.enable_waf
  enable_cloud_guard = true  # Enable for staging
  enable_vulnerability_scanning = true
  
  # Certificate configuration - staging certificate
  enable_ssl_certificate = local.staging_settings.enable_ssl_certificates
  domain_name = var.staging_domain_name
  
  # IAM configuration
  enable_instance_principal = true
  enable_dynamic_groups = true
  
  # Vault configuration - production-like
  vault_type = "DEFAULT"
  enable_vault_backup = true
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
  
  # Staging database settings
  db_name = "libstagedb"
  db_workload = "OLTP"
  
  # Production-like sizing for staging
  is_free_tier = false
  cpu_core_count = 2
  data_storage_size_in_tbs = 1  # 1 TB for staging
  
  # Backup configuration - production-like
  backup_retention_period_in_days = 30
  enable_automatic_backup = true
  
  # Auto-scaling configuration
  is_auto_scaling_enabled = true
  auto_scaling_max_cpu_core_count = 4
  
  # Network access - restricted to private subnet
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
  
  # Staging compute configuration
  compute_shape = local.staging_settings.compute_shape
  compute_ocpus = local.staging_settings.compute_ocpus
  compute_memory_gb = local.staging_settings.compute_memory_gb
  
  # Auto scaling - production-like
  min_instances = local.staging_settings.min_instances
  max_instances = local.staging_settings.max_instances
  desired_instances = local.staging_settings.desired_instances
  auto_scaling_cooldown_seconds = local.staging_settings.auto_scaling_cooldown_seconds
  
  # Load balancer configuration
  enable_load_balancer = true
  load_balancer_shape = "100Mbps"  # Higher capacity for staging
  ssl_certificate_id = module.security.ssl_certificate_id
  
  # Application configuration
  app_port = 8000
  health_check_path = "/health/"
  health_check_interval_ms = 30000  # Production-like interval
  domain_name = var.staging_domain_name
  
  # High availability configuration
  availability_domains = data.oci_identity_availability_domains.ads.availability_domains
  fault_domains = data.oci_identity_fault_domains.fd[*].fault_domains
  
  # Bastion host configuration
  enable_bastion_host = local.staging_settings.enable_bastion_host
  bastion_shape = "VM.Standard.E4.Flex"
  bastion_ocpus = 1
  bastion_memory_gb = 8
  
  # Storage configuration
  create_app_data_volume = true
  app_data_volume_size_gb = 200
  
  # SSH access
  ssh_public_key = var.ssh_public_key
  
  # Production-like configuration
  enable_development_features = false
  install_development_tools = false
  enable_remote_debugging = false
  
  # Performance optimization
  use_spot_instances = false  # No spot instances for staging
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
  waf_policy_id = module.security.waf_policy_id
  object_storage_namespace = var.object_storage_namespace
  
  # Staging monitoring settings
  enable_log_analytics = true
  enable_monitoring_alarms = true
  enable_apm = local.staging_settings.enable_apm
  
  # Production-like retention for staging
  log_retention_days = local.staging_settings.log_retention_days
  audit_log_retention_days = 90
  enable_log_archival = true
  
  # Health check configuration
  health_check_interval_seconds = local.staging_settings.health_check_interval_seconds
  health_check_timeout_seconds = 10
  health_check_protocol = "HTTPS"  # HTTPS for staging
  health_check_path = "/health/"
  health_check_port = 443
  
  # Dashboard configuration
  create_dashboards = true
  
  # Alarm thresholds - production-like
  cpu_alarm_threshold = 75
  memory_alarm_threshold = 80
  response_time_threshold_ms = 3000
  api_error_rate_threshold = 2
  
  # Security monitoring
  enable_security_monitoring = true
  enable_compliance_monitoring = true
  
  # Cost monitoring
  enable_cost_monitoring = true
  monthly_budget_threshold = 1500  # Higher budget for staging
  cost_alert_percentage = 85
}

# ====================================
# Output Values
# ====================================

output "staging_infrastructure" {
  description = "Staging environment infrastructure details"
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
    waf_policy_id = module.security.waf_policy_id
    
    # Monitoring Information
    monitoring_alarms = module.monitoring.monitoring_alarms
    dashboards = module.monitoring.dashboards
    apm_domain_id = module.monitoring.apm_domain_id
    
    # Staging-specific Information
    environment = local.environment
    project_name = local.project_name
    domain_name = var.staging_domain_name
  }
}

output "staging_access_information" {
  description = "Access information for staging environment"
  value = {
    application_endpoints = {
      web_app = "https://${var.staging_domain_name}"
      api = "https://${var.staging_domain_name}/api/v1/"
      admin = "https://${var.staging_domain_name}/admin/"
      health_check = "https://${var.staging_domain_name}/health/"
    }
    
    ssh_access = {
      bastion_host = "ssh -i ~/.ssh/staging_key opc@${module.compute.bastion_public_ip}"
      tunnel_to_app = "ssh -L 8080:${module.compute.load_balancer_ip}:80 -i ~/.ssh/staging_key opc@${module.compute.bastion_public_ip}"
    }
    
    monitoring_urls = {
      oci_console = "https://cloud.oracle.com"
      monitoring = "https://cloud.oracle.com/monitoring/alarms?compartmentId=${var.compartment_ocid}"
      logging = "https://cloud.oracle.com/logging/logs?compartmentId=${var.compartment_ocid}"
      apm = "https://cloud.oracle.com/apm/domains/${module.monitoring.apm_domain_id}"
      dashboards = "https://cloud.oracle.com/management-dashboards"
    }
  }
  sensitive = false
}

# ====================================
# Staging Environment Status
# ====================================

output "staging_status" {
  description = "Staging environment deployment status"
  value = {
    environment = local.environment
    deployment_timestamp = timestamp()
    terraform_workspace = terraform.workspace
    
    infrastructure_status = {
      networking_deployed = true
      security_configured = true
      ssl_enabled = local.staging_settings.enable_ssl_certificates
      waf_enabled = local.staging_settings.enable_waf
      database_ready = true
      compute_running = true
      monitoring_active = true
      apm_enabled = local.staging_settings.enable_apm
    }
    
    production_readiness = {
      ssl_certificates = local.staging_settings.enable_ssl_certificates
      waf_protection = local.staging_settings.enable_waf
      monitoring_comprehensive = local.staging_settings.enable_detailed_monitoring
      backup_configured = true
      auto_scaling_enabled = true
      high_availability = true
    }
    
    security_features = {
      bastion_host = local.staging_settings.enable_bastion_host
      network_security_groups = true
      vault_integration = true
      audit_logging = true
      vulnerability_scanning = true
    }
  }
}

output "staging_performance_metrics" {
  description = "Expected performance metrics for staging environment"
  value = {
    compute_specifications = {
      instance_count = "${local.staging_settings.min_instances}-${local.staging_settings.max_instances}"
      instance_shape = local.staging_settings.compute_shape
      total_ocpus = local.staging_settings.compute_ocpus * local.staging_settings.desired_instances
      total_memory_gb = local.staging_settings.compute_memory_gb * local.staging_settings.desired_instances
    }
    
    database_specifications = {
      cpu_cores = 2
      storage_tb = 1
      auto_scaling_enabled = true
      max_cpu_cores = 4
    }
    
    network_specifications = {
      load_balancer_bandwidth = "100Mbps"
      ssl_termination = true
      waf_protection = local.staging_settings.enable_waf
    }
    
    monitoring_specifications = {
      log_retention_days = local.staging_settings.log_retention_days
      apm_enabled = local.staging_settings.enable_apm
      detailed_monitoring = local.staging_settings.enable_detailed_monitoring
      health_check_interval = local.staging_settings.health_check_interval_seconds
    }
  }
}
