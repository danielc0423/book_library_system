# ====================================
# Compute Module Variables
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# General Configuration Variables
# ====================================

variable "compartment_ocid" {
  description = "The OCID of the compartment where compute resources will be created"
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
# Network Dependencies
# ====================================

variable "vcn_id" {
  description = "The OCID of the VCN"
  type        = string
}

variable "public_subnet_id" {
  description = "The OCID of the public subnet for load balancer"
  type        = string
}

variable "private_subnet_id" {
  description = "The OCID of the private subnet for application instances"
  type        = string
}

variable "lb_nsg_id" {
  description = "The OCID of the load balancer Network Security Group"
  type        = string
}

variable "app_nsg_id" {
  description = "The OCID of the application Network Security Group"
  type        = string
}

variable "bastion_nsg_ids" {
  description = "List of Network Security Group OCIDs for bastion host"
  type        = list(string)
  default     = []
}

# ====================================
# Compute Instance Configuration
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

variable "compute_image_id" {
  description = "OCID of the compute image to use (leave empty for latest Oracle Linux)"
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
  sensitive   = true
}

# ====================================
# Auto Scaling Configuration
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

variable "auto_scaling_cooldown_seconds" {
  description = "Cooldown period in seconds between scaling actions"
  type        = number
  default     = 300
  
  validation {
    condition     = var.auto_scaling_cooldown_seconds >= 60 && var.auto_scaling_cooldown_seconds <= 3600
    error_message = "Cooldown period must be between 60 and 3600 seconds."
  }
}

variable "scale_out_cpu_threshold" {
  description = "CPU utilization threshold for scaling out (percentage)"
  type        = number
  default     = 70
  
  validation {
    condition     = var.scale_out_cpu_threshold >= 1 && var.scale_out_cpu_threshold <= 100
    error_message = "CPU threshold must be between 1 and 100."
  }
}

variable "scale_in_cpu_threshold" {
  description = "CPU utilization threshold for scaling in (percentage)"
  type        = number
  default     = 30
  
  validation {
    condition     = var.scale_in_cpu_threshold >= 1 && var.scale_in_cpu_threshold <= 100
    error_message = "CPU threshold must be between 1 and 100."
  }
}

variable "scale_out_memory_threshold" {
  description = "Memory utilization threshold for scaling out (percentage)"
  type        = number
  default     = 80
  
  validation {
    condition     = var.scale_out_memory_threshold >= 1 && var.scale_out_memory_threshold <= 100
    error_message = "Memory threshold must be between 1 and 100."
  }
}

variable "scale_out_increment" {
  description = "Number of instances to add when scaling out"
  type        = number
  default     = 1
  
  validation {
    condition     = var.scale_out_increment >= 1 && var.scale_out_increment <= 10
    error_message = "Scale out increment must be between 1 and 10."
  }
}

variable "scale_in_decrement" {
  description = "Number of instances to remove when scaling in"
  type        = number
  default     = 1
  
  validation {
    condition     = var.scale_in_decrement >= 1 && var.scale_in_decrement <= 10
    error_message = "Scale in decrement must be between 1 and 10."
  }
}

# ====================================
# Load Balancer Configuration
# ====================================

variable "enable_load_balancer" {
  description = "Enable load balancer creation"
  type        = bool
  default     = true
}

variable "load_balancer_shape" {
  description = "Shape for the load balancer"
  type        = string
  default     = "flexible"
  
  validation {
    condition = contains([
      "10Mbps", "100Mbps", "400Mbps", "8000Mbps", "flexible"
    ], var.load_balancer_shape)
    error_message = "Load balancer shape must be a valid OCI shape."
  }
}

variable "lb_min_bandwidth_mbps" {
  description = "Minimum bandwidth for flexible load balancer (Mbps)"
  type        = number
  default     = 10
  
  validation {
    condition     = var.lb_min_bandwidth_mbps >= 10 && var.lb_min_bandwidth_mbps <= 8000
    error_message = "Minimum bandwidth must be between 10 and 8000 Mbps."
  }
}

variable "lb_max_bandwidth_mbps" {
  description = "Maximum bandwidth for flexible load balancer (Mbps)"
  type        = number
  default     = 100
  
  validation {
    condition     = var.lb_max_bandwidth_mbps >= 10 && var.lb_max_bandwidth_mbps <= 8000
    error_message = "Maximum bandwidth must be between 10 and 8000 Mbps."
  }
}

variable "lb_ip_mode" {
  description = "IP mode for load balancer"
  type        = string
  default     = "IPV4"
  
  validation {
    condition     = contains(["IPV4", "IPV6"], var.lb_ip_mode)
    error_message = "IP mode must be IPV4 or IPV6."
  }
}

variable "ssl_certificate_id" {
  description = "OCID of the SSL certificate for HTTPS listener"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "library.example.com"
}

# ====================================
# Application Configuration
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

variable "health_check_path" {
  description = "Health check path for load balancer"
  type        = string
  default     = "/health/"
}

variable "health_check_interval_ms" {
  description = "Health check interval in milliseconds"
  type        = number
  default     = 30000
  
  validation {
    condition     = var.health_check_interval_ms >= 5000 && var.health_check_interval_ms <= 300000
    error_message = "Health check interval must be between 5000 and 300000 ms."
  }
}

variable "health_check_timeout_ms" {
  description = "Health check timeout in milliseconds"
  type        = number
  default     = 5000
  
  validation {
    condition     = var.health_check_timeout_ms >= 1000 && var.health_check_timeout_ms <= 60000
    error_message = "Health check timeout must be between 1000 and 60000 ms."
  }
}

variable "health_check_retries" {
  description = "Number of health check retries"
  type        = number
  default     = 3
  
  validation {
    condition     = var.health_check_retries >= 1 && var.health_check_retries <= 10
    error_message = "Health check retries must be between 1 and 10."
  }
}

# ====================================
# High Availability Configuration
# ====================================

variable "availability_domains" {
  description = "List of availability domains for instance placement"
  type = list(object({
    name = string
  }))
}

variable "fault_domains" {
  description = "List of fault domains for each availability domain"
  type = list(list(object({
    name = string
  })))
}

variable "enable_cross_ad_placement" {
  description = "Enable placement across multiple availability domains"
  type        = bool
  default     = true
}

# ====================================
# Bastion Host Configuration
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

variable "bastion_ocpus" {
  description = "Number of OCPUs for bastion host"
  type        = number
  default     = 1
  
  validation {
    condition     = var.bastion_ocpus >= 1 && var.bastion_ocpus <= 8
    error_message = "Bastion OCPU count must be between 1 and 8."
  }
}

variable "bastion_memory_gb" {
  description = "Memory in GB for bastion host"
  type        = number
  default     = 4
  
  validation {
    condition     = var.bastion_memory_gb >= 1 && var.bastion_memory_gb <= 128
    error_message = "Bastion memory must be between 1 and 128 GB."
  }
}

# ====================================
# Storage Configuration
# ====================================

variable "create_app_data_volume" {
  description = "Create additional block storage for application data"
  type        = bool
  default     = false
}

variable "app_data_volume_size_gb" {
  description = "Size of application data volume in GB"
  type        = number
  default     = 100
  
  validation {
    condition     = var.app_data_volume_size_gb >= 50 && var.app_data_volume_size_gb <= 32768
    error_message = "App data volume size must be between 50 and 32768 GB."
  }
}

variable "app_data_volume_vpus_per_gb" {
  description = "VPUs per GB for application data volume (performance tier)"
  type        = number
  default     = 10
  
  validation {
    condition     = contains([0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120], var.app_data_volume_vpus_per_gb)
    error_message = "VPUs per GB must be a valid performance tier value."
  }
}

variable "volume_backup_policy_id" {
  description = "OCID of the volume backup policy"
  type        = string
  default     = ""
}

# ====================================
# Custom Image Configuration
# ====================================

variable "create_custom_image" {
  description = "Create custom application image"
  type        = bool
  default     = false
}

variable "custom_image_name" {
  description = "Name for custom application image"
  type        = string
  default     = "library-app-image"
}

# ====================================
# Performance and Optimization
# ====================================

variable "enable_monitoring" {
  description = "Enable instance monitoring"
  type        = bool
  default     = true
}

variable "enable_management" {
  description = "Enable instance management"
  type        = bool
  default     = true
}

variable "enable_vulnerability_scanning" {
  description = "Enable vulnerability scanning on instances"
  type        = bool
  default     = true
}

variable "enable_os_management" {
  description = "Enable OS management service"
  type        = bool
  default     = true
}

# ====================================
# Cost Optimization
# ====================================

variable "use_spot_instances" {
  description = "Use spot instances for cost optimization"
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

variable "preemptible_instance_config" {
  description = "Configuration for preemptible instances"
  type = object({
    preemption_action = object({
      type                 = string
      preserve_boot_volume = bool
    })
  })
  default = {
    preemption_action = {
      type                 = "TERMINATE"
      preserve_boot_volume = false
    }
  }
}

# ====================================
# Security Configuration
# ====================================

variable "disable_legacy_metadata_endpoint" {
  description = "Disable legacy metadata endpoints for security"
  type        = bool
  default     = true
}

variable "enable_secure_boot" {
  description = "Enable secure boot (available on some shapes)"
  type        = bool
  default     = false
}

variable "enable_measured_boot" {
  description = "Enable measured boot (available on some shapes)"
  type        = bool
  default     = false
}

# ====================================
# Maintenance Configuration
# ====================================

variable "maintenance_reboot_preference" {
  description = "Preference for handling reboots during maintenance"
  type        = string
  default     = "LIVE_MIGRATE"
  
  validation {
    condition     = contains(["LIVE_MIGRATE", "REBOOT"], var.maintenance_reboot_preference)
    error_message = "Maintenance reboot preference must be LIVE_MIGRATE or REBOOT."
  }
}

variable "instance_recovery_action" {
  description = "Action to take when instance fails"
  type        = string
  default     = "RESTORE_INSTANCE"
  
  validation {
    condition     = contains(["RESTORE_INSTANCE", "STOP_INSTANCE"], var.instance_recovery_action)
    error_message = "Recovery action must be RESTORE_INSTANCE or STOP_INSTANCE."
  }
}

# ====================================
# Notification Configuration
# ====================================

variable "notification_topic_id" {
  description = "OCID of notification topic for instance events"
  type        = string
  default     = ""
}

variable "enable_instance_principal" {
  description = "Enable instance principal for OCI API access"
  type        = bool
  default     = true
}

# ====================================
# Development Configuration
# ====================================

variable "enable_development_features" {
  description = "Enable development and debugging features"
  type        = bool
  default     = false
}

variable "install_development_tools" {
  description = "Install development tools on instances"
  type        = bool
  default     = false
}

variable "enable_remote_debugging" {
  description = "Enable remote debugging capabilities"
  type        = bool
  default     = false
}
