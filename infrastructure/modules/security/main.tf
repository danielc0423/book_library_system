# ====================================
# Security Module - Main Configuration
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# Network Security Groups (NSGs)
# ====================================

# Load Balancer NSG
resource "oci_core_network_security_group" "load_balancer" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "${var.project_name}-${var.environment}-lb-nsg"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-lb-nsg"
    Type = "security"
    Tier = "load_balancer"
  })
}

# Load Balancer NSG Rules
resource "oci_core_network_security_group_security_rule" "lb_ingress_http" {
  network_security_group_id = oci_core_network_security_group.load_balancer.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }

  description = "Allow HTTP traffic from internet"
}

resource "oci_core_network_security_group_security_rule" "lb_ingress_https" {
  network_security_group_id = oci_core_network_security_group.load_balancer.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }

  description = "Allow HTTPS traffic from internet"
}

resource "oci_core_network_security_group_security_rule" "lb_egress_app" {
  network_security_group_id = oci_core_network_security_group.load_balancer.id
  direction                 = "EGRESS"
  protocol                  = "6" # TCP

  destination      = oci_core_network_security_group.application.id
  destination_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 8000
      max = 8000
    }
  }

  description = "Allow traffic to application servers"
}

# Application NSG
resource "oci_core_network_security_group" "application" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "${var.project_name}-${var.environment}-app-nsg"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-app-nsg"
    Type = "security"
    Tier = "application"
  })
}

# Application NSG Rules
resource "oci_core_network_security_group_security_rule" "app_ingress_lb" {
  network_security_group_id = oci_core_network_security_group.application.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  source      = oci_core_network_security_group.load_balancer.id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 8000
      max = 8000
    }
  }

  description = "Allow traffic from load balancer"
}

resource "oci_core_network_security_group_security_rule" "app_ingress_ssh" {
  count = length(var.allowed_cidr_blocks)
  
  network_security_group_id = oci_core_network_security_group.application.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  source      = var.allowed_cidr_blocks[count.index]
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }

  description = "Allow SSH access from approved sources"
}

resource "oci_core_network_security_group_security_rule" "app_egress_internet" {
  network_security_group_id = oci_core_network_security_group.application.id
  direction                 = "EGRESS"
  protocol                  = "all"

  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"

  description = "Allow all outbound traffic"
}

resource "oci_core_network_security_group_security_rule" "app_egress_db" {
  network_security_group_id = oci_core_network_security_group.application.id
  direction                 = "EGRESS"
  protocol                  = "6" # TCP

  destination      = oci_core_network_security_group.database.id
  destination_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 1521
      max = 1522
    }
  }

  description = "Allow database access"
}

# Database NSG
resource "oci_core_network_security_group" "database" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "${var.project_name}-${var.environment}-db-nsg"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-nsg"
    Type = "security"
    Tier = "database"
  })
}

# Database NSG Rules
resource "oci_core_network_security_group_security_rule" "db_ingress_app" {
  network_security_group_id = oci_core_network_security_group.database.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  source      = oci_core_network_security_group.application.id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 1521
      max = 1522
    }
  }

  description = "Allow database access from application servers"
}

resource "oci_core_network_security_group_security_rule" "db_ingress_analytics" {
  network_security_group_id = oci_core_network_security_group.database.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  source      = oci_core_network_security_group.analytics.id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 1521
      max = 1522
    }
  }

  description = "Allow database access from analytics services"
}

# Analytics NSG
resource "oci_core_network_security_group" "analytics" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "${var.project_name}-${var.environment}-analytics-nsg"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-analytics-nsg"
    Type = "security"
    Tier = "analytics"
  })
}

# Analytics NSG Rules
resource "oci_core_network_security_group_security_rule" "analytics_ingress_app" {
  network_security_group_id = oci_core_network_security_group.analytics.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP

  source      = oci_core_network_security_group.application.id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 9502
      max = 9502
    }
  }

  description = "Allow analytics access from application"
}

resource "oci_core_network_security_group_security_rule" "analytics_egress_all" {
  network_security_group_id = oci_core_network_security_group.analytics.id
  direction                 = "EGRESS"
  protocol                  = "all"

  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"

  description = "Allow all outbound traffic for analytics"
}

# ====================================
# Vault for Secrets Management
# ====================================

resource "oci_kms_vault" "main" {
  compartment_id   = var.compartment_ocid
  display_name     = "${var.project_name}-${var.environment}-vault"
  vault_type       = "DEFAULT"
  
  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-vault"
    Type = "security"
  })
}

# Master Encryption Key
resource "oci_kms_key" "master" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-${var.environment}-master-key"
  management_endpoint = oci_kms_vault.main.management_endpoint

  key_shape {
    algorithm = "AES"
    length    = 32
  }

  protection_mode = "SOFTWARE"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-master-key"
    Type = "encryption"
  })
}

# Database Encryption Key
resource "oci_kms_key" "database" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-${var.environment}-db-key"
  management_endpoint = oci_kms_vault.main.management_endpoint

  key_shape {
    algorithm = "AES"
    length    = 32
  }

  protection_mode = "SOFTWARE"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-key"
    Type = "encryption"
  })
}

# ====================================
# SSL Certificate Management
# ====================================

# Generate private key for SSL certificate
resource "tls_private_key" "ssl" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Generate certificate signing request
resource "tls_cert_request" "ssl" {
  private_key_pem = tls_private_key.ssl.private_key_pem

  subject {
    common_name         = var.domain_name
    organization        = "Library System"
    organizational_unit = "IT Department"
    street_address      = ["123 Library St"]
    locality           = "Library City"
    province           = "Library State"
    country            = "US"
    postal_code        = "12345"
  }

  dns_names = [
    var.domain_name,
    "*.${var.domain_name}",
    "api.${var.domain_name}",
    "admin.${var.domain_name}"
  ]
}

# Self-signed certificate for development
resource "tls_self_signed_cert" "ssl" {
  count = var.environment != "production" ? 1 : 0

  private_key_pem = tls_private_key.ssl.private_key_pem

  subject {
    common_name         = var.domain_name
    organization        = "Library System"
    organizational_unit = "IT Department"
  }

  dns_names = [
    var.domain_name,
    "*.${var.domain_name}",
    "api.${var.domain_name}",
    "admin.${var.domain_name}"
  ]

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Store SSL certificate in OCI Certificates service
resource "oci_certificates_management_certificate" "ssl" {
  certificate_config {
    config_type = "ISSUED_BY_INTERNAL_CA"
    
    certificate_profile_type = "TLS_SERVER_OR_CLIENT"
    
    subject {
      common_name = var.domain_name
    }
    
    subject_alternative_names {
      type  = "DNS"
      value = var.domain_name
    }
    
    subject_alternative_names {
      type  = "DNS"
      value = "*.${var.domain_name}"
    }
    
    validity {
      time_of_validity_not_before = timestamp()
      time_of_validity_not_after  = timeadd(timestamp(), "8760h") # 1 year
    }
    
    key_algorithm = "RSA4096"
  }
  
  compartment_id = var.compartment_ocid
  name          = var.ssl_certificate_name
  description   = "SSL certificate for ${var.domain_name}"

  freeform_tags = merge(var.common_tags, {
    Name = var.ssl_certificate_name
    Type = "ssl_certificate"
  })
}

# ====================================
# IAM Policies
# ====================================

# Dynamic Group for Compute Instances
resource "oci_identity_dynamic_group" "compute_instances" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project_name}-${var.environment}-compute-instances"
  description    = "Dynamic group for compute instances in ${var.environment}"
  
  matching_rule = "ALL {instance.compartment.id = '${var.compartment_ocid}'}"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-compute-instances"
    Type = "iam"
  })
}

# Policy for Compute Instances
resource "oci_identity_policy" "compute_instances" {
  compartment_id = var.compartment_ocid
  name           = "${var.project_name}-${var.environment}-compute-policy"
  description    = "Policy for compute instances to access required resources"
  
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.compute_instances.name} to use keys in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.compute_instances.name} to use secret-family in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.compute_instances.name} to use autonomous-databases in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.compute_instances.name} to use buckets in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.compute_instances.name} to manage objects in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.compute_instances.name} to use log-groups in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.compute_instances.name} to use log-content in compartment id ${var.compartment_ocid}"
  ]

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-compute-policy"
    Type = "iam"
  })
}

# Database Admin Group
resource "oci_identity_group" "database_admins" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project_name}-${var.environment}-db-admins"
  description    = "Database administrators for ${var.environment}"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-admins"
    Type = "iam"
  })
}

# Database Admin Policy
resource "oci_identity_policy" "database_admins" {
  compartment_id = var.compartment_ocid
  name           = "${var.project_name}-${var.environment}-db-admin-policy"
  description    = "Policy for database administrators"
  
  statements = [
    "Allow group ${oci_identity_group.database_admins.name} to manage autonomous-databases in compartment id ${var.compartment_ocid}",
    "Allow group ${oci_identity_group.database_admins.name} to manage autonomous-database-backups in compartment id ${var.compartment_ocid}",
    "Allow group ${oci_identity_group.database_admins.name} to use keys in compartment id ${var.compartment_ocid}",
    "Allow group ${oci_identity_group.database_admins.name} to use secret-family in compartment id ${var.compartment_ocid}"
  ]

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-admin-policy"
    Type = "iam"
  })
}

# Analytics Admins Group
resource "oci_identity_group" "analytics_admins" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project_name}-${var.environment}-analytics-admins"
  description    = "Analytics administrators for ${var.environment}"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-analytics-admins"
    Type = "iam"
  })
}

# Analytics Admin Policy
resource "oci_identity_policy" "analytics_admins" {
  compartment_id = var.compartment_ocid
  name           = "${var.project_name}-${var.environment}-analytics-policy"
  description    = "Policy for analytics administrators"
  
  statements = [
    "Allow group ${oci_identity_group.analytics_admins.name} to manage analytics-instances in compartment id ${var.compartment_ocid}",
    "Allow group ${oci_identity_group.analytics_admins.name} to manage integration-instances in compartment id ${var.compartment_ocid}",
    "Allow group ${oci_identity_group.analytics_admins.name} to use buckets in compartment id ${var.compartment_ocid}",
    "Allow group ${oci_identity_group.analytics_admins.name} to manage objects in compartment id ${var.compartment_ocid}"
  ]

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-analytics-policy"
    Type = "iam"
  })
}

# ====================================
# Cloud Guard Configuration
# ====================================

# Enable Cloud Guard (if not already enabled at tenancy level)
resource "oci_cloud_guard_cloud_guard_configuration" "main" {
  count = var.enable_cloud_guard ? 1 : 0
  
  compartment_id   = var.tenancy_ocid
  reporting_region = var.region
  status          = "ENABLED"
  
  self_manage_resources = false
}

# Cloud Guard Target
resource "oci_cloud_guard_target" "main" {
  count = var.enable_cloud_guard ? 1 : 0
  
  compartment_id            = var.compartment_ocid
  display_name             = "${var.project_name}-${var.environment}-cloud-guard-target"
  target_resource_id       = var.compartment_ocid
  target_resource_type     = "COMPARTMENT"
  
  description = "Cloud Guard target for ${var.project_name} ${var.environment}"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-cloud-guard-target"
    Type = "security"
  })
}

# ====================================
# Vulnerability Scanning
# ====================================

# Vulnerability Scanning Recipe
resource "oci_vulnerability_scanning_host_scan_recipe" "main" {
  count = var.enable_vulnerability_scanning ? 1 : 0
  
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-${var.environment}-vuln-scan-recipe"
  
  port_settings {
    scan_level = "STANDARD"
  }
  
  agent_settings {
    scan_level = "STANDARD"
    agent_configuration {
      vendor = "OCI"
      cis_benchmark_settings {
        scan_level = "STRICT"
      }
    }
  }
  
  application_settings {
    application_scan_level = "STANDARD"
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-vuln-scan-recipe"
    Type = "security"
  })
}

# Vulnerability Scanning Target
resource "oci_vulnerability_scanning_host_scan_target" "main" {
  count = var.enable_vulnerability_scanning ? 1 : 0
  
  compartment_id         = var.compartment_ocid
  display_name          = "${var.project_name}-${var.environment}-vuln-scan-target"
  host_scan_recipe_id   = oci_vulnerability_scanning_host_scan_recipe.main[0].id
  target_compartment_id = var.compartment_ocid
  
  description = "Vulnerability scanning target for ${var.project_name} ${var.environment}"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-vuln-scan-target"
    Type = "security"
  })
}

# ====================================
# Web Application Firewall (WAF)
# ====================================

# WAF Policy
resource "oci_waf_web_app_firewall_policy" "main" {
  count = var.enable_waf ? 1 : 0
  
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}-${var.environment}-waf-policy"
  
  actions {
    name = "allowAction"
    type = "ALLOW"
  }
  
  actions {
    name = "blockAction"
    type = "RETURN_HTTP_RESPONSE"
    body {
      text = "Access Denied"
      type = "STATIC_TEXT"
    }
    code = 403
    headers {
      name  = "Content-Type"
      value = "text/plain"
    }
  }
  
  request_access_control {
    default_action_name = "allowAction"
    
    rules {
      name              = "blockSQLInjection"
      action_name       = "blockAction"
      type             = "ACCESS_CONTROL"
      condition        = "i_contains(keys(http.request.headers), 'user-agent') && i_contains(http.request.headers['user-agent'][0], 'sqlmap')"
      condition_language = "JMESPATH"
    }
  }
  
  request_rate_limiting {
    rules {
      name              = "rateLimitRule"
      action_name       = "blockAction"
      type             = "REQUEST_RATE_LIMITING"
      condition        = "true"
      condition_language = "JMESPATH"
      
      configurations {
        period_in_seconds   = 60
        requests_limit      = 100
        action_duration_in_seconds = 60
      }
    }
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-waf-policy"
    Type = "security"
  })
}
