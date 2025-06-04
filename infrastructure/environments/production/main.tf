# ====================================
# Production Environment Configuration
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

  # Remote State Configuration for Production
  backend "s3" {
    bucket                      = "library-system-terraform-state-prod"
    key                         = "production/terraform.tfstate"
    region                      = "us-ashburn-1"
    endpoint                    = "https://<namespace>.compat.objectstorage.us-ashburn-1.oraclecloud.com"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    force_path_style            = true
    
    # Enhanced security for production state
    encrypt        = true
    kms_key_id     = "ocid1.key.oc1..example1234567890"
    dynamodb_table = "terraform-state-lock-prod"
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
  
  # Production-specific provider configuration
  retry_duration_seconds = 300
  disable_auto_retries   = false
}

provider "random" {}
provider "time" {}

# ====================================
# Local Values for Production
# ====================================

locals {
  environment = "production"
  project_name = "library-system"
  
  # Production-specific settings
  production_settings = {
    # High availability scaling for production
    min_instances = 3
    max_instances = 20
    desired_instances = 5
    
    # High-performance compute shapes
    compute_shape = "VM.Standard.E4.Flex"
    compute_ocpus = 4
    compute_memory_gb = 32
    
    # Comprehensive monitoring for production
    enable_detailed_monitoring = true
    enable_apm = true
    enable_log_analytics = true
    log_retention_days = 90
    
    # Maximum security for production
    enable_bastion_host = true
    enable_ssl_certificates = true
    enable_waf = true
    enable_cloud_guard = true
    enable_vulnerability_scanning = true
    
    # Optimized performance tuning
    health_check_interval_seconds = 15
    auto_scaling_cooldown_seconds = 300
    
    # Multi-region configuration
    enable_cross_region_backup = true
    backup_region = var.backup_region
  }
  
  # Common tags for all production resources
  common_tags = {
    Environment = local.environment
    Project = local.project_name
    Owner = "Operations Team"
    CostCenter = "Production"
    Terraform = "true"
    CreatedBy = "terraform"
    ManagedBy = "library-system-terraform"
    Purpose = "production"
    Criticality = "high"
    BusinessUnit = var.business_unit
    DataClassification = "confidential"
    ComplianceScope = "sox,pci-dss,gdpr"
  }
}

# ====================================
# Data Sources
# ====================================

# Get current availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

# Get fault domains for all ADs
data "oci_identity_fault_domains" "fd" {
  count = length(data.oci_identity_availability_domains.ads.availability_domains)
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[count.index].name
  compartment_id = var.compartment_ocid
}

# Get tenancy details for governance
data "oci_identity_tenancy" "tenancy" {
  tenancy_id = var.tenancy_ocid
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
  
  # VCN Configuration - production network design
  vcn_cidr_block = "10.2.0.0/16"
  vcn_dns_label = "libprodvcn"
  
  # Subnet Configuration with multi-AZ design
  public_subnet_cidr = "10.2.1.0/24"
  private_subnet_cidr = "10.2.2.0/24"
  database_subnet_cidr = "10.2.3.0/24"
  analytics_subnet_cidr = "10.2.4.0/24"
  
  # Additional production subnets
  enable_management_subnet = true
  management_subnet_cidr = "10.2.5.0/24"
  
  # Production network features
  enable_nat_gateway = true
  enable_service_gateway = true
  enable_drg = var.enable_hybrid_connectivity
  enable_vcn_flow_logs = true
  enable_network_monitoring = true
  
  # Security settings - maximum security for production
  allow_ssh_from_internet = false  # Only through bastion
  ssh_allowed_cidrs = []  # No direct SSH access
  
  # Availability configuration - multi-AZ deployment
  availability_domains = data.oci_identity_availability_domains.ads.availability_domains
  
  # Production network optimization
  enable_fastconnect = var.enable_fastconnect
  fastconnect_provider = var.fastconnect_provider
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
  management_subnet_id = module.networking.management_subnet_id
  
  # Maximum security for production
  enable_waf = local.production_settings.enable_waf
  enable_cloud_guard = local.production_settings.enable_cloud_guard
  enable_vulnerability_scanning = local.production_settings.enable_vulnerability_scanning
  enable_security_zones = true
  
  # Certificate configuration - production certificates
  enable_ssl_certificate = local.production_settings.enable_ssl_certificates
  domain_name = var.production_domain_name
  certificate_source = "custom"  # Use enterprise certificates
  
  # Advanced security features
  enable_bastion_service = true  # Use OCI Bastion Service
  enable_data_safe = true
  enable_key_management = true
  
  # IAM configuration - enterprise-grade
  enable_instance_principal = true
  enable_dynamic_groups = true
  enable_identity_domains = true
  
  # Vault configuration - enterprise vault
  vault_type = "DEFAULT"
  enable_vault_backup = true
  enable_vault_replication = true
  vault_backup_region = local.production_settings.backup_region
  
  # Compliance and governance
  enable_audit_log_forwarding = true
  enable_config_management = true
  compliance_frameworks = var.compliance_frameworks
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
  
  # Production database settings
  db_name = "libproddb"
  db_workload = "OLTP"
  
  # High-performance production sizing
  is_free_tier = false
  cpu_core_count = var.db_cpu_core_count
  data_storage_size_in_tbs = var.db_storage_size_tb
  
  # Production backup and recovery
  backup_retention_period_in_days = 30
  enable_automatic_backup = true
  enable_point_in_time_recovery = true
  cross_region_backup_destination = local.production_settings.backup_region
  
  # Auto-scaling configuration
  is_auto_scaling_enabled = true
  auto_scaling_max_cpu_core_count = var.db_max_cpu_core_count
  
  # High availability and disaster recovery
  enable_data_guard = true
  data_guard_type = "ASYNC"
  enable_cross_region_data_guard = var.enable_cross_region_dr
  
  # Network access - highly restricted
  whitelisted_ips = [
    module.networking.private_subnet_cidr,
    module.networking.management_subnet_cidr
  ]
  
  # Advanced features
  enable_database_management = true
  enable_operations_insights = true
  enable_performance_hub = true
  
  # Security configuration
  enable_data_safe_registration = true
  enable_database_vault_integration = true
  
  # Admin credentials from vault
  admin_password = var.db_admin_password
  
  # Maintenance configuration
  maintenance_window_preference = var.db_maintenance_window
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
  
  # High-performance production compute
  compute_shape = local.production_settings.compute_shape
  compute_ocpus = local.production_settings.compute_ocpus
  compute_memory_gb = local.production_settings.compute_memory_gb
  
  # Production auto scaling
  min_instances = local.production_settings.min_instances
  max_instances = local.production_settings.max_instances
  desired_instances = local.production_settings.desired_instances
  auto_scaling_cooldown_seconds = local.production_settings.auto_scaling_cooldown_seconds
  
  # Enhanced scaling policies for production
  scale_out_cpu_threshold = 60  # More aggressive scaling
  scale_in_cpu_threshold = 20
  scale_out_memory_threshold = 70
  scale_in_memory_threshold = 25
  
  # Production load balancer configuration
  enable_load_balancer = true
  load_balancer_shape = "flexible"
  lb_min_bandwidth_mbps = 100
  lb_max_bandwidth_mbps = 8000
  ssl_certificate_id = module.security.ssl_certificate_id
  
  # Application configuration
  app_port = 8000
  health_check_path = "/health/"
  health_check_interval_ms = 15000  # Frequent health checks
  domain_name = var.production_domain_name
  
  # High availability configuration - multi-AZ deployment
  availability_domains = data.oci_identity_availability_domains.ads.availability_domains
  fault_domains = data.oci_identity_fault_domains.fd[*].fault_domains
  enable_cross_ad_placement = true
  
  # Bastion configuration - OCI Bastion Service
  enable_bastion_host = false  # Use OCI Bastion Service instead
  
  # Production storage configuration
  create_app_data_volume = true
  app_data_volume_size_gb = var.app_storage_size_gb
  app_data_volume_vpus_per_gb = 20  # High performance
  
  # SSH access configuration
  ssh_public_key = var.ssh_public_key
  
  # Production security settings
  enable_development_features = false
  install_development_tools = false
  enable_remote_debugging = false
  disable_legacy_metadata_endpoint = true
  enable_secure_boot = true
  enable_measured_boot = true
  
  # Performance optimization
  use_spot_instances = false  # No spot instances for production
  enable_monitoring = true
  enable_management = true
  
  # Instance configuration
  maintenance_reboot_preference = "LIVE_MIGRATE"
  instance_recovery_action = "RESTORE_INSTANCE"
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
  
  # Comprehensive production monitoring
  enable_log_analytics = local.production_settings.enable_log_analytics
  enable_monitoring_alarms = true
  enable_apm = local.production_settings.enable_apm
  apm_free_tier = false  # Use paid tier for production
  
  # Production retention policies
  log_retention_days = local.production_settings.log_retention_days
  audit_log_retention_days = 2555  # 7 years for compliance
  enable_log_archival = true
  log_archive_retention_days = 2555
  
  # Aggressive health monitoring for production
  health_check_interval_seconds = local.production_settings.health_check_interval_seconds
  health_check_timeout_seconds = 5
  health_check_protocol = "HTTPS"
  health_check_path = "/health/"
  health_check_port = 443
  
  # Production dashboards
  create_dashboards = true
  dashboard_refresh_interval = 60  # 1 minute refresh
  
  # Strict alarm thresholds for production
  cpu_alarm_threshold = 70
  memory_alarm_threshold = 75
  response_time_threshold_ms = 2000
  api_error_rate_threshold = 1  # Very low tolerance
  db_connection_threshold = 70
  
  # Advanced monitoring features
  enable_synthetic_monitoring = true
  synthetic_monitor_locations = var.synthetic_monitor_locations
  enable_performance_monitoring = true
  detailed_monitoring = true
  enable_profiling = true
  
  # Security and compliance monitoring
  enable_security_monitoring = true
  enable_compliance_monitoring = true
  security_alert_severity = "WARNING"
  failed_login_threshold = 3
  suspicious_activity_threshold = 5
  
  # Cost monitoring
  enable_cost_monitoring = true
  monthly_budget_threshold = var.production_budget_limit
  cost_alert_percentage = 80
  
  # Integration with external monitoring systems
  enable_third_party_integrations = var.enable_external_monitoring
  third_party_endpoints = var.external_monitoring_endpoints
  
  # Event management
  enable_event_rules = true
  critical_events_only = false
  
  # Performance monitoring
  performance_monitoring_interval = 30  # 30 seconds
  metrics_retention_days = 93  # Maximum retention
}

# ====================================
# Production-Specific Resources
# ====================================

# Global Load Balancer for Multi-Region Setup
resource "oci_dns_steering_policy" "global_lb" {
  count = var.enable_multi_region ? 1 : 0
  
  compartment_id = var.compartment_ocid
  display_name   = "${local.project_name}-${local.environment}-global-lb"
  template       = "FAILOVER"
  
  health_check_monitor_id = oci_health_checks_http_monitor.global_health_check[0].id
  
  rules {
    rule_type = "FAILOVER"
    description = "Primary to secondary region failover"
    
    default_answer_data {
      answer_condition = "answer.isDisabled != true"
      value           = 1
    }
    
    cases {
      answer_data {
        answer_condition = "answer.name == 'primary'"
        value           = 1
      }
      case_condition = "query.client.geoKey in (northAmerica, europe)"
    }
  }
  
  answers {
    name  = "primary"
    rtype = "A"
    rdata = module.compute.load_balancer_ip
    pool  = "primary-pool"
  }
  
  freeform_tags = local.common_tags
}

# Global Health Check for Multi-Region
resource "oci_health_checks_http_monitor" "global_health_check" {
  count = var.enable_multi_region ? 1 : 0
  
  compartment_id      = var.compartment_ocid
  display_name        = "${local.project_name}-${local.environment}-global-health"
  interval_in_seconds = 30
  protocol           = "HTTPS"
  targets            = [module.compute.load_balancer_ip]
  path              = "/health/"
  port              = 443
  timeout_in_seconds = 10
  
  vantage_point_names = [
    "goo-chs",
    "aws-iad",
    "azure-syd"
  ]
  
  is_enabled = true
  
  freeform_tags = local.common_tags
}

# ====================================
# Output Values
# ====================================

output "production_infrastructure" {
  description = "Production environment infrastructure details"
  value = {
    # Network Information
    vcn_id = module.networking.vcn_id
    public_subnet_id = module.networking.public_subnet_id
    private_subnet_id = module.networking.private_subnet_id
    database_subnet_id = module.networking.database_subnet_id
    management_subnet_id = module.networking.management_subnet_id
    
    # Compute Information
    load_balancer_ip = module.compute.load_balancer_ip
    instance_pool_id = module.compute.instance_pool_id
    auto_scaling_config_id = module.compute.auto_scaling_configuration_id
    
    # Database Information
    database_id = module.database.database_id
    database_connection_string = module.database.connection_string
    data_guard_enabled = module.database.data_guard_enabled
    
    # Security Information
    ssl_certificate_id = module.security.ssl_certificate_id
    waf_policy_id = module.security.waf_policy_id
    cloud_guard_enabled = module.security.cloud_guard_enabled
    
    # Monitoring Information
    monitoring_alarms = module.monitoring.monitoring_alarms
    dashboards = module.monitoring.dashboards
    apm_domain_id = module.monitoring.apm_domain_id
    log_analytics_namespace = module.monitoring.log_analytics_namespace
    
    # Production-specific Information
    environment = local.environment
    project_name = local.project_name
    domain_name = var.production_domain_name
    multi_region_enabled = var.enable_multi_region
    global_lb_enabled = var.enable_multi_region
  }
  sensitive = false
}

output "production_access_information" {
  description = "Access information for production environment"
  value = {
    application_endpoints = {
      web_app = "https://${var.production_domain_name}"
      api = "https://${var.production_domain_name}/api/v1/"
      admin = "https://${var.production_domain_name}/admin/"
      health_check = "https://${var.production_domain_name}/health/"
    }
    
    management_access = {
      oci_console = "https://cloud.oracle.com"
      monitoring = "https://cloud.oracle.com/monitoring/alarms?compartmentId=${var.compartment_ocid}"
      logging = "https://cloud.oracle.com/logging/logs?compartmentId=${var.compartment_ocid}"
      apm = "https://cloud.oracle.com/apm/domains/${module.monitoring.apm_domain_id}"
      dashboards = "https://cloud.oracle.com/management-dashboards"
      database_tools = "https://cloud.oracle.com/database/autonomous-databases/${module.database.database_id}"
    }
    
    security_access = {
      cloud_guard = "https://cloud.oracle.com/cloud-guard/overview"
      vault = "https://cloud.oracle.com/security/kms/vaults"
      bastion_service = "https://cloud.oracle.com/bastion/bastions"
      data_safe = "https://cloud.oracle.com/data-safe/overview"
    }
  }
  sensitive = false
}

# ====================================
# Production Environment Status and Metrics
# ====================================

output "production_status" {
  description = "Production environment deployment status and configuration"
  value = {
    environment = local.environment
    deployment_timestamp = timestamp()
    terraform_workspace = terraform.workspace
    
    infrastructure_status = {
      networking_deployed = true
      security_configured = true
      ssl_enabled = local.production_settings.enable_ssl_certificates
      waf_enabled = local.production_settings.enable_waf
      cloud_guard_enabled = local.production_settings.enable_cloud_guard
      database_ready = true
      data_guard_enabled = true
      compute_running = true
      monitoring_active = true
      apm_enabled = local.production_settings.enable_apm
      log_analytics_enabled = local.production_settings.enable_log_analytics
    }
    
    high_availability_features = {
      multi_az_deployment = true
      auto_scaling_enabled = true
      load_balancer_redundancy = true
      database_data_guard = true
      cross_region_backup = local.production_settings.enable_cross_region_backup
      disaster_recovery_configured = var.enable_cross_region_dr
      multi_region_setup = var.enable_multi_region
    }
    
    security_features = {
      network_security_groups = true
      web_application_firewall = local.production_settings.enable_waf
      cloud_guard_monitoring = local.production_settings.enable_cloud_guard
      vulnerability_scanning = local.production_settings.enable_vulnerability_scanning
      data_encryption = true
      key_management = true
      audit_logging = true
      compliance_monitoring = true
      bastion_service = true
      data_safe_integration = true
    }
    
    performance_features = {
      auto_scaling = true
      load_balancing = true
      content_delivery = false  # Can be added if needed
      database_auto_scaling = true
      high_performance_storage = true
      application_performance_monitoring = local.production_settings.enable_apm
    }
  }
}

output "production_capacity_metrics" {
  description = "Production environment capacity and performance metrics"
  value = {
    compute_capacity = {
      min_instances = local.production_settings.min_instances
      max_instances = local.production_settings.max_instances
      current_instances = local.production_settings.desired_instances
      instance_shape = local.production_settings.compute_shape
      total_ocpus = local.production_settings.compute_ocpus * local.production_settings.desired_instances
      total_memory_gb = local.production_settings.compute_memory_gb * local.production_settings.desired_instances
      auto_scaling_enabled = true
    }
    
    database_capacity = {
      cpu_cores = var.db_cpu_core_count
      max_cpu_cores = var.db_max_cpu_core_count
      storage_tb = var.db_storage_size_tb
      auto_scaling_enabled = true
      high_availability = true
      backup_retention_days = 30
    }
    
    network_capacity = {
      load_balancer_bandwidth = "flexible (100-8000 Mbps)"
      ssl_termination = true
      waf_protection = local.production_settings.enable_waf
      global_load_balancing = var.enable_multi_region
    }
    
    monitoring_capacity = {
      log_retention_days = local.production_settings.log_retention_days
      audit_retention_days = 2555
      apm_enabled = local.production_settings.enable_apm
      detailed_monitoring = local.production_settings.enable_detailed_monitoring
      synthetic_monitoring = true
      health_check_interval = local.production_settings.health_check_interval_seconds
    }
  }
}
