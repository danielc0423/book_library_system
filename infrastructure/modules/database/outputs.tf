# ====================================
# Database Module Outputs
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# Autonomous Database Outputs
# ====================================

output "autonomous_database_id" {
  description = "The OCID of the Autonomous Database"
  value       = oci_database_autonomous_database.main.id
}

output "database_name" {
  description = "The database name"
  value       = oci_database_autonomous_database.main.db_name
}

output "database_display_name" {
  description = "The display name of the database"
  value       = oci_database_autonomous_database.main.display_name
}

output "database_state" {
  description = "The current state of the Autonomous Database"
  value       = oci_database_autonomous_database.main.lifecycle_state
}

output "database_cpu_core_count" {
  description = "The number of OCPU cores allocated to the database"
  value       = oci_database_autonomous_database.main.cpu_core_count
}

output "database_storage_size_tbs" {
  description = "The amount of storage allocated to the database in TBs"
  value       = oci_database_autonomous_database.main.data_storage_size_in_tbs
}

output "database_version" {
  description = "The Oracle Database version"
  value       = oci_database_autonomous_database.main.db_version
}

output "database_workload" {
  description = "The Autonomous Database workload type"
  value       = oci_database_autonomous_database.main.db_workload
}

# ====================================
# Database Connection Outputs
# ====================================

output "connection_string_high" {
  description = "High performance connection string"
  value       = oci_database_autonomous_database.main.connection_strings[0].high
  sensitive   = true
}

output "connection_string_medium" {
  description = "Medium performance connection string"
  value       = oci_database_autonomous_database.main.connection_strings[0].medium
  sensitive   = true
}

output "connection_string_low" {
  description = "Low performance connection string"
  value       = oci_database_autonomous_database.main.connection_strings[0].low
  sensitive   = true
}

output "connection_string_tp" {
  description = "Transaction processing connection string"
  value       = oci_database_autonomous_database.main.connection_strings[0].tp
  sensitive   = true
}

output "connection_string_tpurgent" {
  description = "Urgent transaction processing connection string"
  value       = oci_database_autonomous_database.main.connection_strings[0].tpurgent
  sensitive   = true
}

output "connection_strings" {
  description = "All database connection strings"
  value = {
    high     = oci_database_autonomous_database.main.connection_strings[0].high
    medium   = oci_database_autonomous_database.main.connection_strings[0].medium
    low      = oci_database_autonomous_database.main.connection_strings[0].low
    tp       = oci_database_autonomous_database.main.connection_strings[0].tp
    tpurgent = oci_database_autonomous_database.main.connection_strings[0].tpurgent
  }
  sensitive = true
}

# ====================================
# Database Service Outputs
# ====================================

output "service_console_url" {
  description = "The URL of the Service Console for the Autonomous Database"
  value       = oci_database_autonomous_database.main.service_console_url
}

output "apex_url" {
  description = "Oracle Application Express (APEX) URL"
  value       = var.enable_apex ? oci_database_autonomous_database.main.apex_url : null
}

output "machine_learning_url" {
  description = "Oracle Machine Learning URL"
  value       = var.enable_machine_learning ? oci_database_autonomous_database.main.machine_learning_url : null
}

output "graph_studio_url" {
  description = "Oracle Graph Studio URL"
  value       = var.enable_graph ? oci_database_autonomous_database.main.graph_studio_url : null
}

output "sql_developer_web_url" {
  description = "SQL Developer Web URL"
  value       = var.enable_sql_developer_web ? oci_database_autonomous_database.main.sql_developer_web_url : null
}

# ====================================
# Database Wallet Outputs
# ====================================

output "wallet_content" {
  description = "Base64 encoded wallet content"
  value       = data.oci_database_autonomous_database_wallet.main.content
  sensitive   = true
}

output "wallet_download_url" {
  description = "URL to download the database wallet"
  value       = "https://console.${var.region}.oraclecloud.com/db/autonomous/database/${oci_database_autonomous_database.main.id}/wallet"
  sensitive   = true
}

output "wallet_secret_id" {
  description = "OCID of the vault secret containing the wallet"
  value       = var.vault_id != "" && length(oci_vault_secret.wallet) > 0 ? oci_vault_secret.wallet[0].id : null
}

# ====================================
# Database Credentials Outputs
# ====================================

output "admin_username" {
  description = "Database admin username"
  value       = "ADMIN"
}

output "app_username" {
  description = "Application database username"
  value       = var.app_db_username
}

output "app_credentials_secret_id" {
  description = "OCID of the vault secret containing app user credentials"
  value       = var.vault_id != "" && length(oci_vault_secret.app_user_credentials) > 0 ? oci_vault_secret.app_user_credentials[0].id : null
}

# ====================================
# Service Names Outputs
# ====================================

output "service_name" {
  description = "Primary service name for the database"
  value       = "${oci_database_autonomous_database.main.db_name}_high"
}

output "service_names" {
  description = "All available service names"
  value = {
    high     = "${oci_database_autonomous_database.main.db_name}_high"
    medium   = "${oci_database_autonomous_database.main.db_name}_medium"
    low      = "${oci_database_autonomous_database.main.db_name}_low"
    tp       = "${oci_database_autonomous_database.main.db_name}_tp"
    tpurgent = "${oci_database_autonomous_database.main.db_name}_tpurgent"
  }
}

# ====================================
# Backup Outputs
# ====================================

output "weekly_backup_id" {
  description = "OCID of the weekly backup (if enabled)"
  value       = var.enable_manual_backups && length(oci_database_autonomous_database_backup.weekly) > 0 ? oci_database_autonomous_database_backup.weekly[0].id : null
}

output "cross_region_backup_id" {
  description = "OCID of the cross-region backup (if enabled)"
  value       = var.enable_cross_region_backup && length(oci_database_autonomous_database_backup.cross_region) > 0 ? oci_database_autonomous_database_backup.cross_region[0].id : null
}

output "backup_retention_days" {
  description = "Number of days backups are retained"
  value       = var.backup_retention_days
}

# ====================================
# Monitoring Outputs
# ====================================

output "cpu_utilization_alarm_id" {
  description = "OCID of the CPU utilization alarm"
  value       = var.enable_monitoring && length(oci_monitoring_alarm.cpu_utilization) > 0 ? oci_monitoring_alarm.cpu_utilization[0].id : null
}

output "storage_utilization_alarm_id" {
  description = "OCID of the storage utilization alarm"
  value       = var.enable_monitoring && length(oci_monitoring_alarm.storage_utilization) > 0 ? oci_monitoring_alarm.storage_utilization[0].id : null
}

output "session_count_alarm_id" {
  description = "OCID of the session count alarm"
  value       = var.enable_monitoring && length(oci_monitoring_alarm.session_count) > 0 ? oci_monitoring_alarm.session_count[0].id : null
}

output "monitoring_alarms" {
  description = "Map of all monitoring alarm OCIDs"
  value = var.enable_monitoring ? {
    cpu_utilization     = length(oci_monitoring_alarm.cpu_utilization) > 0 ? oci_monitoring_alarm.cpu_utilization[0].id : null
    storage_utilization = length(oci_monitoring_alarm.storage_utilization) > 0 ? oci_monitoring_alarm.storage_utilization[0].id : null
    session_count       = length(oci_monitoring_alarm.session_count) > 0 ? oci_monitoring_alarm.session_count[0].id : null
  } : {}
}

# ====================================
# Performance Configuration Outputs
# ====================================

output "auto_scaling_enabled" {
  description = "Whether auto scaling is enabled"
  value       = oci_database_autonomous_database.main.auto_scaling_enabled
}

output "connection_pool_configuration" {
  description = "Connection pool configuration settings"
  value = {
    initial_size        = var.connection_pool_initial_size
    max_size           = var.connection_pool_max_size
    min_size           = var.connection_pool_min_size
    increment          = var.connection_pool_increment
    connection_timeout = var.connection_timeout_seconds
  }
}

# ====================================
# Database Features Outputs
# ====================================

output "enabled_features" {
  description = "Map of enabled database features"
  value = {
    auto_scaling          = var.auto_scaling_enabled
    database_management   = var.enable_database_management
    apex                 = var.enable_apex
    ords                 = var.enable_ords
    machine_learning     = var.enable_machine_learning
    graph                = var.enable_graph
    sql_developer_web    = var.enable_sql_developer_web
    audit_logging        = var.enable_audit_logging
  }
}

# ====================================
# Database Configuration Summary
# ====================================

output "database_configuration_summary" {
  description = "Complete database configuration summary"
  value = {
    database_info = {
      id           = oci_database_autonomous_database.main.id
      name         = oci_database_autonomous_database.main.db_name
      display_name = oci_database_autonomous_database.main.display_name
      version      = oci_database_autonomous_database.main.db_version
      workload     = oci_database_autonomous_database.main.db_workload
      state        = oci_database_autonomous_database.main.lifecycle_state
    }
    
    performance = {
      cpu_cores              = oci_database_autonomous_database.main.cpu_core_count
      storage_size_tbs       = oci_database_autonomous_database.main.data_storage_size_in_tbs
      auto_scaling_enabled   = oci_database_autonomous_database.main.auto_scaling_enabled
      license_model         = var.license_model
    }
    
    security = {
      mtls_required          = true
      access_control_enabled = true
      wallet_required        = true
      vault_integration     = var.vault_id != ""
    }
    
    features = {
      apex_enabled          = var.enable_apex
      machine_learning      = var.enable_machine_learning
      graph_enabled         = var.enable_graph
      database_management   = var.enable_database_management
      ords_enabled         = var.enable_ords
    }
    
    backup_configuration = {
      manual_backups_enabled    = var.enable_manual_backups
      cross_region_backup      = var.enable_cross_region_backup
      retention_days           = var.backup_retention_days
    }
    
    monitoring = {
      monitoring_enabled       = var.enable_monitoring
      cpu_threshold           = var.cpu_utilization_threshold
      storage_threshold       = var.storage_utilization_threshold
      session_threshold       = var.max_session_threshold
    }
  }
}

# ====================================
# Connection Information Outputs
# ====================================

output "connection_information" {
  description = "Complete connection information for applications"
  value = {
    database_name = oci_database_autonomous_database.main.db_name
    service_names = {
      high     = "${oci_database_autonomous_database.main.db_name}_high"
      medium   = "${oci_database_autonomous_database.main.db_name}_medium"
      low      = "${oci_database_autonomous_database.main.db_name}_low"
      tp       = "${oci_database_autonomous_database.main.db_name}_tp"
      tpurgent = "${oci_database_autonomous_database.main.db_name}_tpurgent"
    }
    
    credentials = {
      admin_username = "ADMIN"
      app_username   = var.app_db_username
    }
    
    connection_requirements = {
      wallet_required = true
      mtls_enabled   = true
      port           = 1521
      protocol       = "TCPS"
    }
    
    urls = {
      service_console    = oci_database_autonomous_database.main.service_console_url
      apex              = var.enable_apex ? oci_database_autonomous_database.main.apex_url : null
      machine_learning  = var.enable_machine_learning ? oci_database_autonomous_database.main.machine_learning_url : null
      sql_developer_web = var.enable_sql_developer_web ? oci_database_autonomous_database.main.sql_developer_web_url : null
    }
  }
  sensitive = true
}

# ====================================
# Cost Information Outputs
# ====================================

output "estimated_monthly_cost" {
  description = "Estimated monthly cost for the database (USD)"
  value = {
    ocpu_cost     = "~$${var.cpu_core_count * 50}"
    storage_cost  = "~$${var.data_storage_size * 0.025}"
    backup_cost   = var.enable_manual_backups ? "~$${var.data_storage_size * 0.005}" : "$0"
    total_estimated = "~$${var.cpu_core_count * 50 + var.data_storage_size * 0.025 + (var.enable_manual_backups ? var.data_storage_size * 0.005 : 0)}"
    
    cost_factors = {
      license_model        = var.license_model
      auto_scaling_enabled = var.auto_scaling_enabled
      backup_enabled      = var.enable_manual_backups
    }
    
    note = "Costs are estimates and may vary based on actual usage and Oracle pricing"
  }
}

# ====================================
# Health Check Outputs
# ====================================

output "health_check_information" {
  description = "Database health check information"
  value = {
    database_state    = oci_database_autonomous_database.main.lifecycle_state
    auto_scaling     = oci_database_autonomous_database.main.auto_scaling_enabled
    backup_enabled   = var.enable_manual_backups
    monitoring_enabled = var.enable_monitoring
    
    performance_metrics = {
      cpu_threshold     = var.cpu_utilization_threshold
      storage_threshold = var.storage_utilization_threshold
      session_threshold = var.max_session_threshold
    }
    
    connection_pool = {
      initial_size = var.connection_pool_initial_size
      max_size    = var.connection_pool_max_size
      timeout     = var.connection_timeout_seconds
    }
  }
}

# ====================================
# Time-based Outputs
# ====================================

output "database_created_time" {
  description = "Timestamp when the database was created"
  value       = time_static.database_created.id
}

output "maintenance_window_rotation" {
  description = "Current maintenance window rotation timestamp"
  value       = time_rotating.maintenance_window.id
}
