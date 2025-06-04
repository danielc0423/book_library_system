# ====================================
# Output Definitions
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# Network Infrastructure Outputs
# ====================================

output "vcn_ocid" {
  description = "The OCID of the Virtual Cloud Network"
  value       = module.networking.vcn_id
}

output "vcn_cidr_block" {
  description = "The CIDR block of the VCN"
  value       = local.vcn_cidr
}

output "public_subnet_ocid" {
  description = "The OCID of the public subnet"
  value       = module.networking.public_subnet_id
}

output "private_subnet_ocid" {
  description = "The OCID of the private subnet"
  value       = module.networking.private_subnet_id
}

output "database_subnet_ocid" {
  description = "The OCID of the database subnet"
  value       = module.networking.database_subnet_id
}

output "analytics_subnet_ocid" {
  description = "The OCID of the analytics subnet"
  value       = module.networking.analytics_subnet_id
}

output "internet_gateway_ocid" {
  description = "The OCID of the Internet Gateway"
  value       = module.networking.internet_gateway_id
}

output "nat_gateway_ocid" {
  description = "The OCID of the NAT Gateway"
  value       = module.networking.nat_gateway_id
}

# ====================================
# Security Infrastructure Outputs
# ====================================

output "load_balancer_security_group_ocid" {
  description = "The OCID of the load balancer security group"
  value       = module.security.load_balancer_nsg_id
}

output "application_security_group_ocid" {
  description = "The OCID of the application security group"
  value       = module.security.application_nsg_id
}

output "database_security_group_ocid" {
  description = "The OCID of the database security group"
  value       = module.security.database_nsg_id
}

output "ssl_certificate_ocid" {
  description = "The OCID of the SSL certificate"
  value       = module.security.ssl_certificate_id
}

output "vault_ocid" {
  description = "The OCID of the vault for secrets management"
  value       = module.security.vault_id
}

# ====================================
# Compute Infrastructure Outputs
# ====================================

output "load_balancer_ocid" {
  description = "The OCID of the load balancer"
  value       = module.compute.load_balancer_id
}

output "load_balancer_ip_address" {
  description = "The public IP address of the load balancer"
  value       = module.compute.load_balancer_public_ip
}

output "instance_pool_ocid" {
  description = "The OCID of the instance pool"
  value       = module.compute.instance_pool_id
}

output "auto_scaling_configuration_ocid" {
  description = "The OCID of the auto scaling configuration"
  value       = module.compute.auto_scaling_config_id
}

output "instance_configuration_ocid" {
  description = "The OCID of the instance configuration"
  value       = module.compute.instance_configuration_id
}

output "bastion_host_ocid" {
  description = "The OCID of the bastion host (if enabled)"
  value       = module.compute.bastion_host_id
}

output "bastion_host_public_ip" {
  description = "The public IP address of the bastion host (if enabled)"
  value       = module.compute.bastion_host_public_ip
}

# ====================================
# Database Infrastructure Outputs
# ====================================

output "autonomous_database_ocid" {
  description = "The OCID of the Autonomous Database"
  value       = module.database.autonomous_database_id
}

output "database_connection_strings" {
  description = "Database connection strings for different service levels"
  value = {
    high     = module.database.connection_string_high
    medium   = module.database.connection_string_medium
    low      = module.database.connection_string_low
    tp       = module.database.connection_string_tp
    tpurgent = module.database.connection_string_tpurgent
  }
  sensitive = true
}

output "database_wallet_download_url" {
  description = "URL to download the database wallet"
  value       = module.database.wallet_download_url
  sensitive   = true
}

output "database_admin_password" {
  description = "The admin password for the database"
  value       = random_password.db_admin_password.result
  sensitive   = true
}

output "app_database_password" {
  description = "The application database user password"
  value       = random_password.app_db_password.result
  sensitive   = true
}

# ====================================
# Monitoring Infrastructure Outputs
# ====================================

output "log_group_ocid" {
  description = "The OCID of the log group"
  value       = module.monitoring.log_group_id
}

output "notification_topic_ocid" {
  description = "The OCID of the notification topic"
  value       = module.monitoring.notification_topic_id
}

output "alarm_ocids" {
  description = "The OCIDs of the monitoring alarms"
  value       = module.monitoring.alarm_ids
}

output "dashboard_url" {
  description = "URL to the monitoring dashboard"
  value       = module.monitoring.dashboard_url
}

# ====================================
# Application Access Outputs
# ====================================

output "application_load_balancer_url" {
  description = "The HTTPS URL of the application"
  value       = "https://${var.domain_name}"
}

output "application_health_check_url" {
  description = "The health check URL of the application"
  value       = "https://${var.domain_name}/health/"
}

output "application_admin_url" {
  description = "The admin URL of the application"
  value       = "https://${var.domain_name}/admin/"
}

output "application_api_url" {
  description = "The API base URL of the application"
  value       = "https://${var.domain_name}/api/v1/"
}

# ====================================
# Analytics and Integration Outputs
# ====================================

output "analytics_cloud_url" {
  description = "URL to access Oracle Analytics Cloud"
  value       = module.monitoring.analytics_cloud_url
}

output "integration_cloud_url" {
  description = "URL to access Oracle Integration Cloud"
  value       = module.monitoring.integration_cloud_url
}

# ====================================
# Connection Information Outputs
# ====================================

output "ssh_connection_commands" {
  description = "SSH connection commands for infrastructure access"
  value = {
    bastion_host = var.enable_bastion_host ? "ssh -i ${var.private_key_path} opc@${module.compute.bastion_host_public_ip}" : "Bastion host not enabled"
    tunnel_command = var.enable_bastion_host ? "ssh -L 8080:${module.compute.load_balancer_private_ip}:80 -i ${var.private_key_path} opc@${module.compute.bastion_host_public_ip}" : "Bastion host not enabled"
  }
  sensitive = true
}

output "database_connection_info" {
  description = "Database connection information"
  value = {
    service_name    = module.database.service_name
    admin_username  = "ADMIN"
    app_username    = "APP_USER"
    port           = "1521"
    protocol       = "TCPS"
    wallet_required = true
  }
  sensitive = true
}

# ====================================
# Cost and Resource Summary Outputs
# ====================================

output "resource_summary" {
  description = "Summary of deployed resources"
  value = {
    environment           = var.environment
    region               = var.region
    availability_domains = local.ad_count
    
    networking = {
      vcn_cidr             = local.vcn_cidr
      public_subnet_cidr   = local.public_subnet_cidr
      private_subnet_cidr  = local.private_subnet_cidr
      database_subnet_cidr = local.database_subnet_cidr
    }
    
    compute = {
      shape           = var.compute_shape
      ocpus          = var.compute_ocpus
      memory_gb      = var.compute_memory_gb
      min_instances  = var.min_instances
      max_instances  = var.max_instances
    }
    
    database = {
      name          = var.db_name
      version       = var.db_version
      cpu_cores     = var.db_cpu_core_count
      storage_gb    = var.db_data_storage_size
      auto_scaling  = var.db_auto_scaling_enabled
    }
    
    security = {
      ssl_enabled     = true
      waf_enabled     = var.enable_waf
      cloud_guard     = var.enable_cloud_guard
      vault_enabled   = true
    }
    
    monitoring = {
      log_retention_days = var.log_retention_days
      alerting_enabled   = true
      dashboard_enabled  = true
    }
  }
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (USD)"
  value = {
    compute_instances = "~$${var.desired_instances * var.compute_ocpus * 30}"
    database         = "~$${var.db_cpu_core_count * 50 + var.db_data_storage_size * 0.025}"
    load_balancer    = "~$25"
    storage          = "~$${var.db_data_storage_size * 0.025}"
    networking       = "~$10"
    monitoring       = "~$15"
    total_estimated  = "~$${var.desired_instances * var.compute_ocpus * 30 + var.db_cpu_core_count * 50 + var.db_data_storage_size * 0.05 + 50}"
    note            = "Estimates are approximate and may vary based on actual usage"
  }
}

# ====================================
# Security and Compliance Outputs
# ====================================

output "security_compliance_info" {
  description = "Security and compliance information"
  value = {
    encryption_at_rest     = "AES-256"
    encryption_in_transit  = "TLS 1.3"
    network_security      = "NSG + Security Lists"
    access_control        = "IAM + Vault"
    monitoring            = "Cloud Guard + Logging"
    backup_encryption     = "AES-256"
    audit_logging         = "Enabled"
  }
}

# ====================================
# Deployment Information Outputs
# ====================================

output "deployment_information" {
  description = "Information about the deployment"
  value = {
    terraform_version = "~> 1.5"
    oci_provider_version = "~> 5.0"
    deployment_time = timestamp()
    
    next_steps = [
      "1. Configure DNS to point ${var.domain_name} to ${module.compute.load_balancer_public_ip}",
      "2. Download and configure database wallet",
      "3. Deploy application using Ansible",
      "4. Configure monitoring alerts",
      "5. Set up backup schedules",
      "6. Configure SSL certificate renewal"
    ]
    
    important_notes = [
      "Database passwords are stored in Terraform state - ensure state is secure",
      "Bastion host is ${var.enable_bastion_host ? "enabled" : "disabled"} for secure access",
      "Auto-scaling is configured for ${var.min_instances}-${var.max_instances} instances",
      "Cross-region backup is ${var.enable_cross_region_backup ? "enabled" : "disabled"}"
    ]
  }
}

# ====================================
# Health Check and Validation Outputs
# ====================================

output "health_check_endpoints" {
  description = "Health check endpoints for monitoring"
  value = {
    load_balancer_health = "https://${var.domain_name}/health/"
    database_health     = "${module.database.connection_string_high}"
    application_status  = "https://${var.domain_name}/api/v1/health/"
    monitoring_status   = module.monitoring.dashboard_url
  }
}

# ====================================
# Environment-Specific Outputs
# ====================================

output "environment_config" {
  description = "Environment-specific configuration"
  value = {
    environment      = var.environment
    multi_ad_enabled = var.enable_multi_ad
    cost_optimization = var.enable_cost_optimization
    development_tools = var.enable_development_tools
    
    scaling_policy = {
      min_instances     = var.min_instances
      max_instances     = var.max_instances
      desired_instances = var.desired_instances
      scaling_enabled   = true
    }
    
    backup_policy = {
      retention_days        = var.backup_retention_days
      cross_region_enabled  = var.enable_cross_region_backup
      automated_backups     = true
    }
  }
}
