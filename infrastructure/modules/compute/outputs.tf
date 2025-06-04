# ====================================
# Compute Module Outputs
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# Instance Pool Outputs
# ====================================

output "instance_pool_id" {
  description = "OCID of the instance pool"
  value       = oci_core_instance_pool.app_servers.id
}

output "instance_pool_size" {
  description = "Current size of the instance pool"
  value       = oci_core_instance_pool.app_servers.size
}

output "instance_pool_state" {
  description = "Current state of the instance pool"
  value       = oci_core_instance_pool.app_servers.state
}

output "instance_pool_instances" {
  description = "List of instances in the pool"
  value       = oci_core_instance_pool.app_servers.instance_configuration_id
}

# ====================================
# Auto Scaling Outputs
# ====================================

output "auto_scaling_configuration_id" {
  description = "OCID of the auto scaling configuration"
  value       = oci_autoscaling_auto_scaling_configuration.app_servers.id
}

output "auto_scaling_state" {
  description = "Current state of auto scaling configuration"
  value       = oci_autoscaling_auto_scaling_configuration.app_servers.is_enabled
}

output "auto_scaling_cooldown" {
  description = "Auto scaling cooldown period in seconds"
  value       = oci_autoscaling_auto_scaling_configuration.app_servers.cool_down_in_seconds
}

output "scaling_policy_details" {
  description = "Details of the scaling policy"
  value = {
    min_instances = var.min_instances
    max_instances = var.max_instances
    desired_instances = var.desired_instances
    scale_out_cpu_threshold = var.scale_out_cpu_threshold
    scale_in_cpu_threshold = var.scale_in_cpu_threshold
  }
}

# ====================================
# Load Balancer Outputs
# ====================================

output "load_balancer_id" {
  description = "OCID of the load balancer"
  value       = var.enable_load_balancer ? oci_load_balancer.main[0].id : null
}

output "load_balancer_ip" {
  description = "IP address of the load balancer"
  value       = var.enable_load_balancer ? oci_load_balancer.main[0].ip_address_details[0].ip_address : null
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = var.enable_load_balancer ? "${oci_load_balancer.main[0].display_name}.${oci_load_balancer.main[0].compartment_id}.oci.customer-oci.com" : null
}

output "load_balancer_shape" {
  description = "Shape of the load balancer"
  value       = var.enable_load_balancer ? oci_load_balancer.main[0].shape : null
}

output "load_balancer_state" {
  description = "Current state of the load balancer"
  value       = var.enable_load_balancer ? oci_load_balancer.main[0].state : null
}

output "load_balancer_backend_set_name" {
  description = "Name of the backend set"
  value       = var.enable_load_balancer ? oci_load_balancer_backend_set.app_servers[0].name : null
}

output "load_balancer_listeners" {
  description = "Load balancer listener configurations"
  value = var.enable_load_balancer ? {
    http_listener = {
      name = oci_load_balancer_listener.http[0].name
      port = oci_load_balancer_listener.http[0].port
      protocol = oci_load_balancer_listener.http[0].protocol
    }
    https_listener = var.ssl_certificate_id != "" ? {
      name = oci_load_balancer_listener.https[0].name
      port = oci_load_balancer_listener.https[0].port
      protocol = oci_load_balancer_listener.https[0].protocol
    } : null
  } : null
}

# ====================================
# Bastion Host Outputs
# ====================================

output "bastion_instance_id" {
  description = "OCID of the bastion host instance"
  value       = var.enable_bastion_host ? oci_core_instance.bastion[0].id : null
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = var.enable_bastion_host ? oci_core_instance.bastion[0].public_ip : null
}

output "bastion_private_ip" {
  description = "Private IP address of the bastion host"
  value       = var.enable_bastion_host ? oci_core_instance.bastion[0].private_ip : null
}

output "bastion_state" {
  description = "Current state of the bastion host"
  value       = var.enable_bastion_host ? oci_core_instance.bastion[0].state : null
}

output "bastion_ssh_connection" {
  description = "SSH connection command for bastion host"
  value       = var.enable_bastion_host ? "ssh -i /path/to/private_key opc@${oci_core_instance.bastion[0].public_ip}" : null
  sensitive   = false
}

# ====================================
# Instance Configuration Outputs
# ====================================

output "instance_configuration_id" {
  description = "OCID of the instance configuration"
  value       = oci_core_instance_configuration.app_server.id
}

output "instance_configuration_name" {
  description = "Display name of the instance configuration"
  value       = oci_core_instance_configuration.app_server.display_name
}

output "compute_image_id" {
  description = "OCID of the compute image being used"
  value       = var.compute_image_id != "" ? var.compute_image_id : data.oci_core_images.oracle_linux.images[0].id
}

output "compute_shape_details" {
  description = "Details of the compute shape configuration"
  value = {
    shape = var.compute_shape
    ocpus = var.compute_ocpus
    memory_gb = var.compute_memory_gb
    boot_volume_size_gb = var.boot_volume_size_gb
  }
}

# ====================================
# Storage Outputs
# ====================================

output "app_data_volumes" {
  description = "List of application data volume OCIDs"
  value       = var.create_app_data_volume ? oci_core_volume.app_data[*].id : []
}

output "app_data_volume_details" {
  description = "Details of application data volumes"
  value = var.create_app_data_volume ? {
    volume_ids = oci_core_volume.app_data[*].id
    size_gb = var.app_data_volume_size_gb
    vpus_per_gb = var.app_data_volume_vpus_per_gb
    backup_policy_id = var.volume_backup_policy_id
  } : null
}

# ====================================
# Custom Image Outputs
# ====================================

output "custom_image_id" {
  description = "OCID of the custom application image"
  value       = var.create_custom_image ? oci_core_image.custom_app_image[0].id : null
}

output "custom_image_state" {
  description = "State of the custom application image"
  value       = var.create_custom_image ? oci_core_image.custom_app_image[0].state : null
}

# ====================================
# Health Check and Monitoring Outputs
# ====================================

output "health_check_configuration" {
  description = "Health check configuration details"
  value = {
    path = var.health_check_path
    interval_ms = var.health_check_interval_ms
    timeout_ms = var.health_check_timeout_ms
    retries = var.health_check_retries
    port = var.app_port
  }
}

output "monitoring_configuration" {
  description = "Monitoring and management configuration"
  value = {
    monitoring_enabled = var.enable_monitoring
    management_enabled = var.enable_management
    vulnerability_scanning_enabled = var.enable_vulnerability_scanning
    os_management_enabled = var.enable_os_management
  }
}

# ====================================
# Network Configuration Outputs
# ====================================

output "network_configuration" {
  description = "Network configuration details for compute resources"
  value = {
    vcn_id = var.vcn_id
    public_subnet_id = var.public_subnet_id
    private_subnet_id = var.private_subnet_id
    lb_nsg_id = var.lb_nsg_id
    app_nsg_id = var.app_nsg_id
    bastion_nsg_ids = var.bastion_nsg_ids
  }
}

# ====================================
# Application Configuration Outputs
# ====================================

output "application_configuration" {
  description = "Application-specific configuration details"
  value = {
    app_port = var.app_port
    domain_name = var.domain_name
    ssl_certificate_id = var.ssl_certificate_id
    health_check_path = var.health_check_path
  }
}

# ====================================
# High Availability Configuration Outputs
# ====================================

output "high_availability_configuration" {
  description = "High availability configuration details"
  value = {
    availability_domains = var.availability_domains
    fault_domains = var.fault_domains
    cross_ad_placement_enabled = var.enable_cross_ad_placement
    instance_recovery_action = var.instance_recovery_action
    maintenance_reboot_preference = var.maintenance_reboot_preference
  }
}

# ====================================
# Security Configuration Outputs
# ====================================

output "security_configuration" {
  description = "Security configuration details"
  value = {
    legacy_metadata_disabled = var.disable_legacy_metadata_endpoint
    secure_boot_enabled = var.enable_secure_boot
    measured_boot_enabled = var.enable_measured_boot
    instance_principal_enabled = var.enable_instance_principal
  }
}

# ====================================
# Cost Optimization Outputs
# ====================================

output "cost_optimization_configuration" {
  description = "Cost optimization configuration details"
  value = {
    spot_instances_enabled = var.use_spot_instances
    spot_instance_percentage = var.spot_instance_percentage
    preemptible_config = var.preemptible_instance_config
  }
}

# ====================================
# Summary Outputs for Integration
# ====================================

output "compute_summary" {
  description = "Complete summary of compute infrastructure"
  value = {
    # Core Resources
    instance_pool_id = oci_core_instance_pool.app_servers.id
    auto_scaling_id = oci_autoscaling_auto_scaling_configuration.app_servers.id
    load_balancer_id = var.enable_load_balancer ? oci_load_balancer.main[0].id : null
    load_balancer_ip = var.enable_load_balancer ? oci_load_balancer.main[0].ip_address_details[0].ip_address : null
    bastion_instance_id = var.enable_bastion_host ? oci_core_instance.bastion[0].id : null
    bastion_public_ip = var.enable_bastion_host ? oci_core_instance.bastion[0].public_ip : null
    
    # Configuration Details
    instance_count = {
      min = var.min_instances
      max = var.max_instances
      desired = var.desired_instances
    }
    
    compute_specs = {
      shape = var.compute_shape
      ocpus = var.compute_ocpus
      memory_gb = var.compute_memory_gb
    }
    
    # Network Integration
    network_integration = {
      vcn_id = var.vcn_id
      public_subnet_id = var.public_subnet_id
      private_subnet_id = var.private_subnet_id
      lb_nsg_id = var.lb_nsg_id
      app_nsg_id = var.app_nsg_id
    }
    
    # Application Configuration
    application = {
      port = var.app_port
      health_check_path = var.health_check_path
      domain_name = var.domain_name
    }
    
    # Security Features
    security = {
      ssl_enabled = var.ssl_certificate_id != ""
      bastion_enabled = var.enable_bastion_host
      monitoring_enabled = var.enable_monitoring
    }
  }
}

# ====================================
# Terraform State Outputs
# ====================================

output "terraform_workspace" {
  description = "Current Terraform workspace"
  value       = terraform.workspace
}

output "deployment_timestamp" {
  description = "Timestamp of deployment"
  value       = timestamp()
}

output "compute_module_version" {
  description = "Version of the compute module"
  value       = "1.0.0"
}

# ====================================
# Integration Points for Other Modules
# ====================================

output "integration_endpoints" {
  description = "Integration endpoints for other modules and external systems"
  value = {
    # Load Balancer Integration
    load_balancer = var.enable_load_balancer ? {
      id = oci_load_balancer.main[0].id
      ip_address = oci_load_balancer.main[0].ip_address_details[0].ip_address
      backend_set_name = oci_load_balancer_backend_set.app_servers[0].name
      listeners = {
        http_port = 80
        https_port = var.ssl_certificate_id != "" ? 443 : null
      }
    } : null
    
    # Instance Pool Integration
    instance_pool = {
      id = oci_core_instance_pool.app_servers.id
      configuration_id = oci_core_instance_configuration.app_server.id
      auto_scaling_id = oci_autoscaling_auto_scaling_configuration.app_servers.id
    }
    
    # Bastion Integration
    bastion = var.enable_bastion_host ? {
      id = oci_core_instance.bastion[0].id
      public_ip = oci_core_instance.bastion[0].public_ip
      private_ip = oci_core_instance.bastion[0].private_ip
    } : null
    
    # Storage Integration
    storage = var.create_app_data_volume ? {
      volume_ids = oci_core_volume.app_data[*].id
      volume_size_gb = var.app_data_volume_size_gb
    } : null
  }
}
