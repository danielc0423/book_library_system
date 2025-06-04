# ====================================
# Database Module - Main Configuration
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# Autonomous Database Instance
# ====================================

resource "oci_database_autonomous_database" "main" {
  compartment_id           = var.compartment_ocid
  db_name                 = var.db_name
  display_name            = "${var.project_name}-${var.environment}-${var.db_name}"
  
  # Database Configuration
  cpu_core_count          = var.cpu_core_count
  data_storage_size_in_tbs = var.data_storage_size / 1024  # Convert GB to TB
  db_version              = var.db_version
  
  # Performance and Scaling
  auto_scaling_enabled         = var.auto_scaling_enabled
  auto_scaling_for_storage_enabled = var.auto_scaling_enabled
  
  # Network Configuration
  subnet_id              = var.subnet_id
  nsg_ids               = var.nsg_ids
  is_access_control_enabled = true
  
  # Security Configuration
  admin_password        = var.db_admin_password
  is_mtls_connection_required = true
  
  # Backup Configuration
  is_auto_scaling_for_storage_enabled = var.auto_scaling_enabled
  
  # License Configuration
  license_model = var.license_model
  
  # Workload Type
  db_workload = var.db_workload
  
  # Additional Configuration
  character_set    = "AL32UTF8"
  ncharacter_set  = "AL16UTF16"
  
  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.db_name}"
    Type = "database"
    Tier = "database"
  })
  
  # Lifecycle management
  lifecycle {
    ignore_changes = [
      admin_password,  # Password managed separately
      defined_tags
    ]
    prevent_destroy = true  # Prevent accidental deletion
  }
}

# ====================================
# Database Backup Configuration
# ====================================

resource "oci_database_autonomous_database_backup" "weekly" {
  count = var.enable_manual_backups ? 1 : 0
  
  autonomous_database_id = oci_database_autonomous_database.main.id
  display_name          = "${var.project_name}-${var.environment}-weekly-backup"
  type                  = "FULL"
  
  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-weekly-backup"
    Type = "backup"
    Schedule = "weekly"
  })
}

# ====================================
# Database Wallet Management
# ====================================

data "oci_database_autonomous_database_wallet" "main" {
  autonomous_database_id = oci_database_autonomous_database.main.id
  password              = var.wallet_password
  generate_type         = "SINGLE"
  base64_encode_content = true
}

# Store wallet in OCI Vault (if vault is provided)
resource "oci_vault_secret" "wallet" {
  count = var.vault_id != "" ? 1 : 0
  
  compartment_id = var.compartment_ocid
  vault_id      = var.vault_id
  key_id        = var.vault_key_id
  secret_name   = "${var.project_name}-${var.environment}-db-wallet"
  
  secret_content {
    content_type = "BASE64"
    content     = data.oci_database_autonomous_database_wallet.main.content
  }
  
  description = "Database wallet for ${var.project_name} ${var.environment}"
  
  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-wallet"
    Type = "secret"
  })
}

# ====================================
# Application Database User
# ====================================

# This would typically be done via SQL scripts, but we can prepare the structure
resource "oci_vault_secret" "app_user_credentials" {
  count = var.vault_id != "" ? 1 : 0
  
  compartment_id = var.compartment_ocid
  vault_id      = var.vault_id
  key_id        = var.vault_key_id
  secret_name   = "${var.project_name}-${var.environment}-app-db-credentials"
  
  secret_content {
    content_type = "APPLICATION_JSON"
    content     = base64encode(jsonencode({
      username = var.app_db_username
      password = var.app_db_password
    }))
  }
  
  description = "Application database user credentials"
  
  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-app-db-credentials"
    Type = "secret"
  })
}

# ====================================
# Database Connection Endpoints
# ====================================

# Local file for connection configuration (for applications)
resource "local_file" "database_connection_config" {
  count = var.create_connection_config ? 1 : 0
  
  filename = "${path.module}/database_connection.json"
  content = jsonencode({
    connection_strings = {
      high     = oci_database_autonomous_database.main.connection_strings[0].high
      medium   = oci_database_autonomous_database.main.connection_strings[0].medium
      low      = oci_database_autonomous_database.main.connection_strings[0].low
      tp       = oci_database_autonomous_database.main.connection_strings[0].tp
      tpurgent = oci_database_autonomous_database.main.connection_strings[0].tpurgent
    }
    
    service_console_url = oci_database_autonomous_database.main.service_console_url
    apex_url           = oci_database_autonomous_database.main.apex_url
    
    database_info = {
      db_name          = oci_database_autonomous_database.main.db_name
      display_name     = oci_database_autonomous_database.main.display_name
      cpu_core_count   = oci_database_autonomous_database.main.cpu_core_count
      data_storage_size = oci_database_autonomous_database.main.data_storage_size_in_tbs
      db_version       = oci_database_autonomous_database.main.db_version
      is_auto_scaling_enabled = oci_database_autonomous_database.main.auto_scaling_enabled
    }
    
    credentials = {
      admin_username = "ADMIN"
      app_username   = var.app_db_username
      wallet_required = true
    }
  })
  
  file_permission = "0600"  # Restrict access to owner only
}

# ====================================
# Database Monitoring and Alerts
# ====================================

# Database Performance Monitoring
resource "oci_monitoring_alarm" "cpu_utilization" {
  count = var.enable_monitoring ? 1 : 0
  
  compartment_id        = var.compartment_ocid
  display_name         = "${var.project_name}-${var.environment}-db-cpu-high"
  metric_compartment_id = var.compartment_ocid
  namespace            = "oci_autonomous_database"
  
  query                = "CpuUtilization[1m].mean() > ${var.cpu_utilization_threshold}"
  severity            = "WARNING"
  
  destinations = var.notification_topic_id != "" ? [var.notification_topic_id] : []
  
  is_enabled = true
  
  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-cpu-high"
    Type = "monitoring"
  })
}

resource "oci_monitoring_alarm" "storage_utilization" {
  count = var.enable_monitoring ? 1 : 0
  
  compartment_id        = var.compartment_ocid
  display_name         = "${var.project_name}-${var.environment}-db-storage-high"
  metric_compartment_id = var.compartment_ocid
  namespace            = "oci_autonomous_database"
  
  query                = "StorageUtilization[1m].mean() > ${var.storage_utilization_threshold}"
  severity            = "CRITICAL"
  
  destinations = var.notification_topic_id != "" ? [var.notification_topic_id] : []
  
  is_enabled = true
  
  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-storage-high"
    Type = "monitoring"
  })
}

# Database Connection Monitoring
resource "oci_monitoring_alarm" "session_count" {
  count = var.enable_monitoring ? 1 : 0
  
  compartment_id        = var.compartment_ocid
  display_name         = "${var.project_name}-${var.environment}-db-sessions-high"
  metric_compartment_id = var.compartment_ocid
  namespace            = "oci_autonomous_database"
  
  query                = "CurrentLoggedInSessions[1m].mean() > ${var.max_session_threshold}"
  severity            = "WARNING"
  
  destinations = var.notification_topic_id != "" ? [var.notification_topic_id] : []
  
  is_enabled = true
  
  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-sessions-high"
    Type = "monitoring"
  })
}

# ====================================
# Database Initialization Scripts
# ====================================

# Null resource to run database initialization
resource "null_resource" "database_initialization" {
  count = var.run_init_scripts ? 1 : 0
  
  depends_on = [oci_database_autonomous_database.main]
  
  triggers = {
    database_id = oci_database_autonomous_database.main.id
    script_hash = filemd5("${path.module}/scripts/init_database.sql")
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Database initialization would run here"
      echo "Database ID: ${oci_database_autonomous_database.main.id}"
      echo "Service Name: ${oci_database_autonomous_database.main.db_name}_high"
      echo "Connection String: ${oci_database_autonomous_database.main.connection_strings[0].high}"
    EOT
  }
}

# ====================================
# Database Performance Insights
# ====================================

# Enable Database Management for performance insights
resource "oci_database_management_managed_database" "main" {
  count = var.enable_database_management ? 1 : 0
  
  database_id      = oci_database_autonomous_database.main.id
  management_type  = "ADVANCED"
  service_name    = "${oci_database_autonomous_database.main.db_name}_high"
  
  credential_details {
    user_name          = "ADMIN"
    password_secret_id = var.vault_id != "" ? oci_vault_secret.app_user_credentials[0].id : null
  }
  
  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-management"
    Type = "database_management"
  })
}

# ====================================
# Cross-Region Backup (if enabled)
# ====================================

resource "oci_database_autonomous_database_backup" "cross_region" {
  count = var.enable_cross_region_backup ? 1 : 0
  
  autonomous_database_id = oci_database_autonomous_database.main.id
  display_name          = "${var.project_name}-${var.environment}-cross-region-backup"
  type                  = "FULL"
  
  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-cross-region-backup"
    Type = "backup"
    Schedule = "cross_region"
  })
}

# ====================================
# Database Tools Integration
# ====================================

# Oracle APEX Workspace (if enabled)
resource "null_resource" "apex_workspace" {
  count = var.enable_apex ? 1 : 0
  
  depends_on = [oci_database_autonomous_database.main]
  
  triggers = {
    database_id = oci_database_autonomous_database.main.id
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "APEX workspace configuration would be set up here"
      echo "APEX URL: ${oci_database_autonomous_database.main.apex_url}"
    EOT
  }
}

# ====================================
# Database Connection Pooling Configuration
# ====================================

resource "local_file" "connection_pool_config" {
  count = var.create_connection_config ? 1 : 0
  
  filename = "${path.module}/connection_pool.json"
  content = jsonencode({
    pool_settings = {
      initial_pool_size     = var.connection_pool_initial_size
      max_pool_size        = var.connection_pool_max_size
      min_pool_size        = var.connection_pool_min_size
      pool_increment       = var.connection_pool_increment
      connection_timeout   = var.connection_timeout_seconds
      validate_connection  = true
      test_on_borrow      = true
      test_on_return      = false
    }
    
    service_names = {
      high_performance = "${oci_database_autonomous_database.main.db_name}_high"
      medium_performance = "${oci_database_autonomous_database.main.db_name}_medium" 
      low_performance = "${oci_database_autonomous_database.main.db_name}_low"
      transaction_processing = "${oci_database_autonomous_database.main.db_name}_tp"
      urgent_processing = "${oci_database_autonomous_database.main.db_name}_tpurgent"
    }
    
    failover_settings = {
      enable_failover = true
      retry_count    = 3
      retry_delay    = 5
    }
  })
  
  file_permission = "0600"
}

# ====================================
# Time-based Operations
# ====================================

# Create a time resource for tracking creation
resource "time_static" "database_created" {}

# Schedule for maintenance windows
resource "time_rotating" "maintenance_window" {
  rotation_days = 7  # Weekly rotation
}
