# ====================================
# Security Module Outputs
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# Network Security Group Outputs
# ====================================

output "load_balancer_nsg_id" {
  description = "The OCID of the load balancer Network Security Group"
  value       = var.enable_network_security_groups ? oci_core_network_security_group.load_balancer.id : null
}

output "application_nsg_id" {
  description = "The OCID of the application Network Security Group"
  value       = var.enable_network_security_groups ? oci_core_network_security_group.application.id : null
}

output "database_nsg_id" {
  description = "The OCID of the database Network Security Group"
  value       = var.enable_network_security_groups ? oci_core_network_security_group.database.id : null
}

output "analytics_nsg_id" {
  description = "The OCID of the analytics Network Security Group"
  value       = var.enable_network_security_groups ? oci_core_network_security_group.analytics.id : null
}

output "network_security_groups" {
  description = "Map of all Network Security Group OCIDs"
  value = var.enable_network_security_groups ? {
    load_balancer = oci_core_network_security_group.load_balancer.id
    application   = oci_core_network_security_group.application.id
    database      = oci_core_network_security_group.database.id
    analytics     = oci_core_network_security_group.analytics.id
  } : {}
}

# ====================================
# Vault and Encryption Outputs
# ====================================

output "vault_id" {
  description = "The OCID of the vault"
  value       = oci_kms_vault.main.id
}

output "vault_crypto_endpoint" {
  description = "The crypto endpoint of the vault"
  value       = oci_kms_vault.main.crypto_endpoint
}

output "vault_management_endpoint" {
  description = "The management endpoint of the vault"
  value       = oci_kms_vault.main.management_endpoint
}

output "master_key_id" {
  description = "The OCID of the master encryption key"
  value       = oci_kms_key.master.id
}

output "database_key_id" {
  description = "The OCID of the database encryption key"
  value       = oci_kms_key.database.id
}

output "encryption_keys" {
  description = "Map of all encryption key OCIDs"
  value = {
    master   = oci_kms_key.master.id
    database = oci_kms_key.database.id
  }
}

# ====================================
# SSL Certificate Outputs
# ====================================

output "ssl_certificate_id" {
  description = "The OCID of the SSL certificate"
  value       = oci_certificates_management_certificate.ssl.id
}

output "ssl_certificate_name" {
  description = "The name of the SSL certificate"
  value       = oci_certificates_management_certificate.ssl.name
}

output "ssl_private_key_pem" {
  description = "The private key for the SSL certificate (sensitive)"
  value       = tls_private_key.ssl.private_key_pem
  sensitive   = true
}

output "ssl_certificate_pem" {
  description = "The SSL certificate in PEM format (for dev environments)"
  value       = var.environment != "production" ? tls_self_signed_cert.ssl[0].cert_pem : null
  sensitive   = true
}

output "ssl_cert_request_pem" {
  description = "The certificate signing request in PEM format"
  value       = tls_cert_request.ssl.cert_request_pem
  sensitive   = true
}

# ====================================
# IAM Policy and Group Outputs
# ====================================

output "compute_dynamic_group_id" {
  description = "The OCID of the compute instances dynamic group"
  value       = var.create_iam_resources ? oci_identity_dynamic_group.compute_instances.id : null
}

output "database_admin_group_id" {
  description = "The OCID of the database admin group"
  value       = var.create_iam_resources ? oci_identity_group.database_admins.id : null
}

output "analytics_admin_group_id" {
  description = "The OCID of the analytics admin group"
  value       = var.create_iam_resources ? oci_identity_group.analytics_admins.id : null
}

output "iam_policy_ids" {
  description = "Map of all IAM policy OCIDs"
  value = var.create_iam_resources ? {
    compute_instances = oci_identity_policy.compute_instances.id
    database_admins   = oci_identity_policy.database_admins.id
    analytics_admins  = oci_identity_policy.analytics_admins.id
  } : {}
}

output "iam_group_ids" {
  description = "Map of all IAM group OCIDs"
  value = var.create_iam_resources ? {
    database_admins  = oci_identity_group.database_admins.id
    analytics_admins = oci_identity_group.analytics_admins.id
  } : {}
}

# ====================================
# Security Monitoring Outputs
# ====================================

output "cloud_guard_configuration_id" {
  description = "The OCID of the Cloud Guard configuration"
  value       = var.enable_cloud_guard && length(oci_cloud_guard_cloud_guard_configuration.main) > 0 ? oci_cloud_guard_cloud_guard_configuration.main[0].id : null
}

output "cloud_guard_target_id" {
  description = "The OCID of the Cloud Guard target"
  value       = var.enable_cloud_guard && length(oci_cloud_guard_target.main) > 0 ? oci_cloud_guard_target.main[0].id : null
}

output "vulnerability_scan_recipe_id" {
  description = "The OCID of the vulnerability scanning recipe"
  value       = var.enable_vulnerability_scanning && length(oci_vulnerability_scanning_host_scan_recipe.main) > 0 ? oci_vulnerability_scanning_host_scan_recipe.main[0].id : null
}

output "vulnerability_scan_target_id" {
  description = "The OCID of the vulnerability scanning target"
  value       = var.enable_vulnerability_scanning && length(oci_vulnerability_scanning_host_scan_target.main) > 0 ? oci_vulnerability_scanning_host_scan_target.main[0].id : null
}

# ====================================
# WAF Outputs
# ====================================

output "waf_policy_id" {
  description = "The OCID of the WAF policy"
  value       = var.enable_waf && length(oci_waf_web_app_firewall_policy.main) > 0 ? oci_waf_web_app_firewall_policy.main[0].id : null
}

output "waf_policy_name" {
  description = "The name of the WAF policy"
  value       = var.enable_waf && length(oci_waf_web_app_firewall_policy.main) > 0 ? oci_waf_web_app_firewall_policy.main[0].display_name : null
}

# ====================================
# Security Configuration Summary
# ====================================

output "security_configuration_summary" {
  description = "Summary of security configuration"
  value = {
    network_security_groups_enabled = var.enable_network_security_groups
    vault_enabled                   = true
    ssl_certificate_configured      = true
    iam_policies_created           = var.create_iam_resources
    cloud_guard_enabled            = var.enable_cloud_guard
    vulnerability_scanning_enabled  = var.enable_vulnerability_scanning
    waf_enabled                    = var.enable_waf
    encryption_at_rest_enabled     = var.enable_encryption_at_rest
    
    compliance_features = {
      audit_logging_enabled     = var.enable_audit_logging
      data_classification      = var.enable_data_classification
      security_monitoring      = var.enable_security_monitoring
      compliance_standards     = var.compliance_standards
    }
    
    network_security = {
      load_balancer_ports = var.load_balancer_ports
      application_ports   = var.application_ports
      database_ports      = var.database_ports
      analytics_ports     = var.analytics_ports
      allowed_cidr_blocks = var.allowed_cidr_blocks
    }
  }
}

# ====================================
# Security Health Check Outputs
# ====================================

output "security_health_checks" {
  description = "Security health check endpoints and status"
  value = {
    vault_status = {
      id       = oci_kms_vault.main.id
      state    = oci_kms_vault.main.vault_type
      endpoint = oci_kms_vault.main.management_endpoint
    }
    
    ssl_certificate_status = {
      id          = oci_certificates_management_certificate.ssl.id
      name        = oci_certificates_management_certificate.ssl.name
      state       = oci_certificates_management_certificate.ssl.lifecycle_state
    }
    
    security_monitoring = {
      cloud_guard_enabled            = var.enable_cloud_guard
      vulnerability_scanning_enabled = var.enable_vulnerability_scanning
      waf_enabled                   = var.enable_waf
    }
    
    encryption_status = {
      vault_id     = oci_kms_vault.main.id
      master_key   = oci_kms_key.master.id
      database_key = oci_kms_key.database.id
    }
  }
}

# ====================================
# Security Compliance Outputs
# ====================================

output "security_compliance_report" {
  description = "Security compliance status report"
  value = {
    encryption = {
      at_rest_enabled     = var.enable_encryption_at_rest
      in_transit_enabled  = true  # SSL/TLS
      key_management     = "customer_managed"
      algorithm          = var.key_algorithm
      key_length         = var.key_length
    }
    
    access_control = {
      network_security_groups = var.enable_network_security_groups
      iam_policies_enabled   = var.create_iam_resources
      least_privilege        = true
      multi_factor_auth      = "idcs_integrated"
    }
    
    monitoring_and_logging = {
      cloud_guard_enabled       = var.enable_cloud_guard
      vulnerability_scanning    = var.enable_vulnerability_scanning
      audit_logging            = var.enable_audit_logging
      security_monitoring      = var.enable_security_monitoring
      data_retention_days      = var.data_retention_days
    }
    
    network_security = {
      waf_enabled               = var.enable_waf
      ddos_protection          = "oci_native"
      network_segmentation     = "multi_tier"
      secure_communication     = "ssl_tls"
    }
    
    compliance_standards = {
      standards_covered = var.compliance_standards
      data_classification = var.enable_data_classification
      regular_assessments = var.enable_vulnerability_scanning
    }
  }
}

# ====================================
# Cost Estimation Outputs
# ====================================

output "estimated_monthly_security_cost" {
  description = "Estimated monthly cost for security components (USD)"
  value = {
    vault_and_keys        = var.enable_encryption_at_rest ? "~$1-5" : "$0"
    cloud_guard          = var.enable_cloud_guard ? "~$0" : "$0"
    vulnerability_scanning = var.enable_vulnerability_scanning ? "~$0-20" : "$0"
    waf                  = var.enable_waf ? "~$0-50" : "$0"
    ssl_certificates     = "~$0-10"
    bastion_service      = var.enable_bastion_service ? "~$0-5" : "$0"
    
    total_estimated = var.enable_encryption_at_rest && var.enable_waf ? "~$1-90" : "~$0-30"
    note           = "Costs vary based on usage and features enabled"
  }
}

# ====================================
# Security Best Practices Status
# ====================================

output "security_best_practices_status" {
  description = "Status of security best practices implementation"
  value = {
    identity_and_access = {
      principle_of_least_privilege = true
      role_based_access_control   = var.create_iam_resources
      multi_factor_authentication = "idcs_integrated"
      regular_access_reviews      = "manual_process"
    }
    
    data_protection = {
      encryption_at_rest    = var.enable_encryption_at_rest
      encryption_in_transit = true
      data_classification   = var.enable_data_classification
      data_loss_prevention = var.enable_cloud_guard
    }
    
    security_monitoring = {
      continuous_monitoring     = var.enable_security_monitoring
      threat_detection         = var.enable_cloud_guard
      vulnerability_management = var.enable_vulnerability_scanning
      incident_response        = "manual_process"
    }
    
    network_security = {
      network_segmentation      = true
      firewall_protection      = var.enable_waf
      intrusion_detection      = var.enable_cloud_guard
      secure_remote_access     = var.enable_bastion_service
    }
    
    compliance_and_governance = {
      policy_enforcement       = var.create_iam_resources
      audit_logging           = var.enable_audit_logging
      compliance_monitoring   = var.enable_cloud_guard
      regular_assessments     = var.enable_vulnerability_scanning
    }
  }
}
