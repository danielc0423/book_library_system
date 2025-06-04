# ====================================
# Compute Module - Main Configuration
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# Data Sources
# ====================================

# Get the most recent Oracle Linux image
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

# Get fault domains for high availability
data "oci_identity_fault_domains" "ads" {
  count               = length(var.availability_domains)
  availability_domain = var.availability_domains[count.index].name
  compartment_id      = var.compartment_ocid
}

# ====================================
# Instance Configuration Template
# ====================================

resource "oci_core_instance_configuration" "app_server" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-${var.environment}-app-config"

  instance_details {
    instance_type = "compute"

    launch_details {
      compartment_id      = var.compartment_ocid
      shape              = var.compute_shape
      availability_domain = var.availability_domains[0].name

      # Flexible shape configuration
      shape_config {
        ocpus         = var.compute_ocpus
        memory_in_gbs = var.compute_memory_gb
      }

      # Instance source
      source_details {
        source_type = "image"
        image_id    = var.compute_image_id != "" ? var.compute_image_id : data.oci_core_images.oracle_linux.images[0].id
      }

      # Network configuration
      create_vnic_details {
        subnet_id        = var.private_subnet_id
        nsg_ids         = [var.app_nsg_id]
        assign_public_ip = false
        hostname_label   = "app-server"
      }

      # SSH key for access
      metadata = {
        ssh_authorized_keys = var.ssh_public_key
        user_data = base64encode(templatefile("${path.module}/scripts/user_data.sh", {
          project_name = var.project_name
          environment  = var.environment
          app_port     = var.app_port
        }))
      }

      # Boot volume configuration
      source_details {
        source_type             = "image"
        image_id               = var.compute_image_id != "" ? var.compute_image_id : data.oci_core_images.oracle_linux.images[0].id
        boot_volume_size_in_gbs = var.boot_volume_size_gb
      }

      # Agent configuration
      agent_config {
        is_monitoring_enabled = true
        is_management_enabled = true
        
        plugins_config {
          name          = "Vulnerability Scanning"
          desired_state = "ENABLED"
        }
        
        plugins_config {
          name          = "Oracle Java Management Service"
          desired_state = "ENABLED"
        }
        
        plugins_config {
          name          = "OS Management Service Agent"
          desired_state = "ENABLED"
        }
      }

      # Instance options
      instance_options {
        are_legacy_imds_endpoints_disabled = true
      }

      # Availability configuration
      availability_config {
        recovery_action = "RESTORE_INSTANCE"
      }
    }
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-app-config"
    Type = "compute"
  })
}

# ====================================
# Instance Pool for Auto Scaling
# ====================================

resource "oci_core_instance_pool" "app_servers" {
  compartment_id            = var.compartment_ocid
  instance_configuration_id = oci_core_instance_configuration.app_server.id
  display_name             = "${var.project_name}-${var.environment}-app-pool"
  
  # Size configuration
  size = var.desired_instances

  # Placement configurations across availability domains
  dynamic "placement_configurations" {
    for_each = var.availability_domains
    content {
      availability_domain = placement_configurations.value.name
      primary_subnet_id   = var.private_subnet_id
      
      # Fault domain distribution
      dynamic "fault_domains" {
        for_each = var.fault_domains[placement_configurations.key]
        content {
          fault_domain = fault_domains.value.name
        }
      }
    }
  }

  # Load balancer attachment
  dynamic "load_balancers" {
    for_each = var.enable_load_balancer ? [1] : []
    content {
      load_balancer_id = oci_load_balancer.main[0].id
      backend_set_name = oci_load_balancer_backend_set.app_servers[0].name
      port             = var.app_port
      vnic_selection   = "PrimaryVnic"
    }
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-app-pool"
    Type = "compute"
  })
}

# ====================================
# Auto Scaling Configuration
# ====================================

resource "oci_autoscaling_auto_scaling_configuration" "app_servers" {
  compartment_id       = var.compartment_ocid
  display_name        = "${var.project_name}-${var.environment}-autoscaling"
  cool_down_in_seconds = var.auto_scaling_cooldown_seconds
  is_enabled          = true

  # Auto scaling policy
  policies {
    display_name = "${var.project_name}-${var.environment}-scaling-policy"
    policy_type  = "threshold"
    capacity {
      initial = var.desired_instances
      max     = var.max_instances
      min     = var.min_instances
    }

    # Scale-out rule (CPU > 70%)
    rules {
      display_name = "scale_out_on_cpu"
      action {
        type  = "CHANGE_COUNT_BY"
        value = var.scale_out_increment
      }
      metric {
        metric_type = "CPU_UTILIZATION"
        threshold {
          operator = "GT"
          value    = var.scale_out_cpu_threshold
        }
      }
    }

    # Scale-in rule (CPU < 30%)
    rules {
      display_name = "scale_in_on_cpu"
      action {
        type  = "CHANGE_COUNT_BY"
        value = -var.scale_in_decrement
      }
      metric {
        metric_type = "CPU_UTILIZATION"
        threshold {
          operator = "LT"
          value    = var.scale_in_cpu_threshold
        }
      }
    }

    # Scale-out rule on memory (Memory > 80%)
    rules {
      display_name = "scale_out_on_memory"
      action {
        type  = "CHANGE_COUNT_BY"
        value = var.scale_out_increment
      }
      metric {
        metric_type = "MEMORY_UTILIZATION"
        threshold {
          operator = "GT"
          value    = var.scale_out_memory_threshold
        }
      }
    }
  }

  auto_scaling_resources {
    id   = oci_core_instance_pool.app_servers.id
    type = "instancePool"
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-autoscaling"
    Type = "compute"
  })
}

# ====================================
# Load Balancer
# ====================================

resource "oci_load_balancer" "main" {
  count = var.enable_load_balancer ? 1 : 0

  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-${var.environment}-lb"
  shape          = var.load_balancer_shape
  subnet_ids     = [var.public_subnet_id]

  # Flexible shape configuration
  dynamic "shape_details" {
    for_each = var.load_balancer_shape == "flexible" ? [1] : []
    content {
      minimum_bandwidth_in_mbps = var.lb_min_bandwidth_mbps
      maximum_bandwidth_in_mbps = var.lb_max_bandwidth_mbps
    }
  }

  # Network Security Groups
  network_security_group_ids = [var.lb_nsg_id]

  # IP mode
  ip_mode    = var.lb_ip_mode
  is_private = false

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-lb"
    Type = "load_balancer"
  })
}

# ====================================
# Load Balancer Backend Set
# ====================================

resource "oci_load_balancer_backend_set" "app_servers" {
  count = var.enable_load_balancer ? 1 : 0

  load_balancer_id = oci_load_balancer.main[0].id
  name            = "${var.project_name}-${var.environment}-backend-set"
  policy          = "ROUND_ROBIN"

  health_checker {
    protocol            = "HTTP"
    interval_ms         = var.health_check_interval_ms
    port                = var.app_port
    retries             = var.health_check_retries
    timeout_in_millis   = var.health_check_timeout_ms
    url_path           = var.health_check_path
    return_code        = 200
  }

  session_persistence_configuration {
    cookie_name      = "lb-session"
    disable_fallback = false
  }
}

# ====================================
# Load Balancer Listeners
# ====================================

# HTTP Listener (redirects to HTTPS)
resource "oci_load_balancer_listener" "http" {
  count = var.enable_load_balancer ? 1 : 0

  load_balancer_id         = oci_load_balancer.main[0].id
  name                    = "http-listener"
  default_backend_set_name = oci_load_balancer_backend_set.app_servers[0].name
  port                    = 80
  protocol                = "HTTP"

  # Redirect HTTP to HTTPS
  rule_set_names = [oci_load_balancer_rule_set.redirect_to_https[0].name]
}

# HTTPS Listener
resource "oci_load_balancer_listener" "https" {
  count = var.enable_load_balancer && var.ssl_certificate_id != "" ? 1 : 0

  load_balancer_id         = oci_load_balancer.main[0].id
  name                    = "https-listener"
  default_backend_set_name = oci_load_balancer_backend_set.app_servers[0].name
  port                    = 443
  protocol                = "HTTP"

  ssl_configuration {
    certificate_ids                   = [var.ssl_certificate_id]
    verify_peer_certificate          = false
    verify_depth                     = 1
    server_order_preference          = "ENABLED"
    cipher_suite_name               = "oci-default-ssl-cipher-suite-v1"
    protocols                       = ["TLSv1.2", "TLSv1.3"]
  }

  rule_set_names = [
    oci_load_balancer_rule_set.security_headers[0].name,
    oci_load_balancer_rule_set.compression[0].name
  ]
}

# ====================================
# Load Balancer Rule Sets
# ====================================

# HTTP to HTTPS redirect rule set
resource "oci_load_balancer_rule_set" "redirect_to_https" {
  count = var.enable_load_balancer ? 1 : 0

  load_balancer_id = oci_load_balancer.main[0].id
  name            = "redirect-to-https"

  items {
    action = "REDIRECT"
    redirect_uri {
      protocol = "HTTPS"
      host     = "{host}"
      port     = 443
      path     = "{path}"
      query    = "{query}"
    }
    response_code = 301
  }
}

# Security headers rule set
resource "oci_load_balancer_rule_set" "security_headers" {
  count = var.enable_load_balancer ? 1 : 0

  load_balancer_id = oci_load_balancer.main[0].id
  name            = "security-headers"

  items {
    action = "ADD_HTTP_RESPONSE_HEADER"
    header = "Strict-Transport-Security"
    value  = "max-age=31536000; includeSubDomains"
  }

  items {
    action = "ADD_HTTP_RESPONSE_HEADER"
    header = "X-Content-Type-Options"
    value  = "nosniff"
  }

  items {
    action = "ADD_HTTP_RESPONSE_HEADER"
    header = "X-Frame-Options"
    value  = "DENY"
  }

  items {
    action = "ADD_HTTP_RESPONSE_HEADER"
    header = "X-XSS-Protection"
    value  = "1; mode=block"
  }

  items {
    action = "ADD_HTTP_RESPONSE_HEADER"
    header = "Referrer-Policy"
    value  = "strict-origin-when-cross-origin"
  }
}

# Compression rule set
resource "oci_load_balancer_rule_set" "compression" {
  count = var.enable_load_balancer ? 1 : 0

  load_balancer_id = oci_load_balancer.main[0].id
  name            = "compression"

  items {
    action = "CONTROL_ACCESS_USING_HTTP_METHODS"
    allowed_methods = ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"]
    status_code     = 405
  }
}

# ====================================
# Bastion Host (if enabled)
# ====================================

resource "oci_core_instance" "bastion" {
  count = var.enable_bastion_host ? 1 : 0

  availability_domain = var.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "${var.project_name}-${var.environment}-bastion"
  shape              = var.bastion_shape

  # Flexible shape configuration
  shape_config {
    ocpus         = var.bastion_ocpus
    memory_in_gbs = var.bastion_memory_gb
  }

  # Instance source
  source_details {
    source_type             = "image"
    image_id               = data.oci_core_images.oracle_linux.images[0].id
    boot_volume_size_in_gbs = 50
  }

  # Network configuration
  create_vnic_details {
    subnet_id                 = var.public_subnet_id
    assign_public_ip         = true
    assign_private_dns_record = true
    hostname_label           = "bastion"
    nsg_ids                  = var.bastion_nsg_ids
  }

  # SSH key and user data
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/scripts/bastion_user_data.sh", {
      project_name = var.project_name
      environment  = var.environment
    }))
  }

  # Agent configuration
  agent_config {
    is_monitoring_enabled = true
    is_management_enabled = true
  }

  # Instance options
  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  # Fault tolerance
  availability_config {
    recovery_action = "RESTORE_INSTANCE"
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-bastion"
    Type = "bastion"
  })

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }
}

# ====================================
# Block Storage for Application Data
# ====================================

resource "oci_core_volume" "app_data" {
  count = var.create_app_data_volume ? var.desired_instances : 0

  availability_domain = var.availability_domains[count.index % length(var.availability_domains)].name
  compartment_id      = var.compartment_ocid
  display_name        = "${var.project_name}-${var.environment}-app-data-${count.index + 1}"
  size_in_gbs        = var.app_data_volume_size_gb

  # Performance tier
  vpus_per_gb = var.app_data_volume_vpus_per_gb

  # Backup policy
  backup_policy_id = var.volume_backup_policy_id

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-app-data-${count.index + 1}"
    Type = "storage"
  })
}

# ====================================
# Custom Images (if specified)
# ====================================

resource "oci_core_image" "custom_app_image" {
  count = var.create_custom_image ? 1 : 0

  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-${var.environment}-app-image"
  
  # This would be created from an existing instance
  # instance_id = oci_core_instance.template_instance[0].id
  
  launch_mode = "NATIVE"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-app-image"
    Type = "custom_image"
  })
}
