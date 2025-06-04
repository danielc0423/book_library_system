# ====================================
# Provider Configuration
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# Terraform Configuration Block
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
    
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
    
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
  
  # Backend configuration for remote state
  # This should be configured per environment
  backend "s3" {
    # Oracle Object Storage with S3 compatibility
    # These values should be overridden in environment-specific configurations
    bucket                      = "terraform-state"
    key                        = "library-system/terraform.tfstate"
    region                     = "us-ashburn-1"
    endpoint                   = "https://objectstorage.us-ashburn-1.oraclecloud.com"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style           = true
    
    # State locking using DynamoDB equivalent (optional)
    # dynamodb_table = "terraform-state-lock"
  }
}

# ====================================
# Oracle Cloud Infrastructure Provider
# ====================================

provider "oci" {
  # Authentication Configuration
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
  
  # Additional provider configuration
  retry_duration_seconds = 60
  
  # Ignore certain changes to prevent unnecessary updates
  ignore_defined_tags = ["Oracle-Tags.CreatedBy", "Oracle-Tags.CreatedOn"]
}

# Alternative authentication using instance principal (for running from OCI instances)
provider "oci" {
  alias        = "instance_principal"
  region       = var.region
  auth         = "InstancePrincipal"
  
  # Use this provider when running Terraform from OCI compute instances
  # with appropriate IAM policies
}

# Alternative authentication using resource principal (for OCI Functions/Container Instances)
provider "oci" {
  alias        = "resource_principal"
  region       = var.region
  auth         = "ResourcePrincipal"
  
  # Use this provider when running Terraform from OCI managed services
}

# ====================================
# Random Provider
# ====================================

provider "random" {
  # No additional configuration needed
}

# ====================================
# Time Provider
# ====================================

provider "time" {
  # No additional configuration needed
}

# ====================================
# TLS Provider
# ====================================

provider "tls" {
  # No additional configuration needed
}

# ====================================
# Local Provider
# ====================================

provider "local" {
  # No additional configuration needed
}

# ====================================
# Null Provider
# ====================================

provider "null" {
  # No additional configuration needed
}

# ====================================
# Provider Configuration Validation
# ====================================

# Validate that the OCI provider is properly configured
data "oci_identity_tenancy" "current" {
  tenancy_id = var.tenancy_ocid
}

# Validate that the user has proper permissions
data "oci_identity_user" "current" {
  user_id = var.user_ocid
}

# Check available regions
data "oci_identity_regions" "available" {}

# Validate compartment access
data "oci_identity_compartment" "current" {
  id = var.compartment_ocid
}

# ====================================
# Provider Feature Flags
# ====================================

# Configure provider features based on environment
locals {
  provider_features = {
    enable_retry_logic       = true
    enable_request_logging   = var.environment != "production"
    enable_debug_logging     = var.environment == "development"
    max_retry_duration      = var.environment == "production" ? 120 : 60
    request_timeout         = var.environment == "production" ? 300 : 120
  }
}

# ====================================
# Provider Version Constraints
# ====================================

# Ensure we're using compatible provider versions
check "provider_version_check" {
  assert {
    condition = can(data.oci_identity_tenancy.current.id)
    error_message = "OCI provider is not properly configured or authenticated. Please check your credentials and tenancy configuration."
  }
}

check "compartment_access_check" {
  assert {
    condition = can(data.oci_identity_compartment.current.id)
    error_message = "Cannot access the specified compartment. Please check the compartment OCID and your permissions."
  }
}

check "region_validity_check" {
  assert {
    condition = contains([for region in data.oci_identity_regions.available.regions : region.name], var.region)
    error_message = "The specified region is not available for this tenancy."
  }
}

# ====================================
# Provider Configuration Outputs
# ====================================

# Output provider configuration information for debugging
output "provider_configuration" {
  description = "Provider configuration information"
  value = {
    oci_provider_version = "~> 5.0"
    terraform_version   = "~> 1.5"
    tenancy_name       = data.oci_identity_tenancy.current.name
    user_name          = data.oci_identity_user.current.name
    region             = var.region
    compartment_name   = data.oci_identity_compartment.current.name
    available_regions  = [for region in data.oci_identity_regions.available.regions : region.name]
  }
  sensitive = false
}

# ====================================
# Provider Error Handling
# ====================================

# Create a null resource to validate provider configuration
resource "null_resource" "provider_validation" {
  triggers = {
    tenancy_ocid     = var.tenancy_ocid
    user_ocid        = var.user_ocid
    compartment_ocid = var.compartment_ocid
    region           = var.region
  }
  
  provisioner "local-exec" {
    command = "echo 'Provider validation successful for ${data.oci_identity_tenancy.current.name}'"
  }
}

# ====================================
# Multi-Region Provider Configuration (if needed)
# ====================================

# Additional provider for disaster recovery region (optional)
provider "oci" {
  alias            = "dr_region"
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.enable_cross_region_backup ? "us-phoenix-1" : var.region
}

# ====================================
# Provider Aliases for Different Use Cases
# ====================================

# Provider alias for identity operations (always use home region)
provider "oci" {
  alias            = "home_region"
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = data.oci_identity_tenancy.current.home_region_key
}

# ====================================
# Provider Configuration Best Practices
# ====================================

# Note: Best practices for provider configuration:
# 1. Use environment variables for sensitive values when possible
# 2. Implement proper state file encryption and access controls
# 3. Use separate provider configurations for different environments
# 4. Implement proper retry and timeout configurations
# 5. Use provider aliases for multi-region deployments
# 6. Validate provider configuration before resource creation
# 7. Use instance/resource principals when running from OCI
# 8. Implement proper error handling and validation checks
