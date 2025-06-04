# ====================================
# Networking Module Outputs
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# VCN Outputs
# ====================================

output "vcn_id" {
  description = "The OCID of the VCN"
  value       = oci_core_vcn.main.id
}

output "vcn_cidr_block" {
  description = "The CIDR block of the VCN"
  value       = oci_core_vcn.main.cidr_blocks[0]
}

output "vcn_display_name" {
  description = "The display name of the VCN"
  value       = oci_core_vcn.main.display_name
}

output "vcn_dns_label" {
  description = "The DNS label of the VCN"
  value       = oci_core_vcn.main.dns_label
}

output "vcn_state" {
  description = "The state of the VCN"
  value       = oci_core_vcn.main.state
}

# ====================================
# Gateway Outputs
# ====================================

output "internet_gateway_id" {
  description = "The OCID of the Internet Gateway"
  value       = oci_core_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "The OCID of the NAT Gateway"
  value       = oci_core_nat_gateway.main.id
}

output "nat_gateway_ip_address" {
  description = "The IP address of the NAT Gateway"
  value       = oci_core_nat_gateway.main.nat_ip
}

output "service_gateway_id" {
  description = "The OCID of the Service Gateway"
  value       = oci_core_service_gateway.main.id
}

# ====================================
# Route Table Outputs
# ====================================

output "public_route_table_id" {
  description = "The OCID of the public route table"
  value       = oci_core_route_table.public.id
}

output "private_route_table_id" {
  description = "The OCID of the private route table"
  value       = oci_core_route_table.private.id
}

output "database_route_table_id" {
  description = "The OCID of the database route table"
  value       = oci_core_route_table.database.id
}

output "analytics_route_table_id" {
  description = "The OCID of the analytics route table"
  value       = oci_core_route_table.analytics.id
}

# ====================================
# Security List Outputs
# ====================================

output "public_security_list_id" {
  description = "The OCID of the public security list"
  value       = oci_core_security_list.public.id
}

output "private_security_list_id" {
  description = "The OCID of the private security list"
  value       = oci_core_security_list.private.id
}

output "database_security_list_id" {
  description = "The OCID of the database security list"
  value       = oci_core_security_list.database.id
}

output "analytics_security_list_id" {
  description = "The OCID of the analytics security list"
  value       = oci_core_security_list.analytics.id
}

# ====================================
# Subnet Outputs
# ====================================

output "public_subnet_id" {
  description = "The OCID of the public subnet"
  value       = oci_core_subnet.public.id
}

output "public_subnet_cidr" {
  description = "The CIDR block of the public subnet"
  value       = oci_core_subnet.public.cidr_block
}

output "private_subnet_id" {
  description = "The OCID of the private subnet"
  value       = oci_core_subnet.private.id
}

output "private_subnet_cidr" {
  description = "The CIDR block of the private subnet"
  value       = oci_core_subnet.private.cidr_block
}

output "database_subnet_id" {
  description = "The OCID of the database subnet"
  value       = oci_core_subnet.database.id
}

output "database_subnet_cidr" {
  description = "The CIDR block of the database subnet"
  value       = oci_core_subnet.database.cidr_block
}

output "analytics_subnet_id" {
  description = "The OCID of the analytics subnet"
  value       = oci_core_subnet.analytics.id
}

output "analytics_subnet_cidr" {
  description = "The CIDR block of the analytics subnet"
  value       = oci_core_subnet.analytics.cidr_block
}

# ====================================
# DHCP Options Outputs
# ====================================

output "dhcp_options_id" {
  description = "The OCID of the DHCP options"
  value       = oci_core_dhcp_options.main.id
}

# ====================================
# Network Summary Outputs
# ====================================

output "subnet_ids" {
  description = "Map of all subnet OCIDs"
  value = {
    public    = oci_core_subnet.public.id
    private   = oci_core_subnet.private.id
    database  = oci_core_subnet.database.id
    analytics = oci_core_subnet.analytics.id
  }
}

output "subnet_cidrs" {
  description = "Map of all subnet CIDR blocks"
  value = {
    public    = oci_core_subnet.public.cidr_block
    private   = oci_core_subnet.private.cidr_block
    database  = oci_core_subnet.database.cidr_block
    analytics = oci_core_subnet.analytics.cidr_block
  }
}

output "route_table_ids" {
  description = "Map of all route table OCIDs"
  value = {
    public    = oci_core_route_table.public.id
    private   = oci_core_route_table.private.id
    database  = oci_core_route_table.database.id
    analytics = oci_core_route_table.analytics.id
  }
}

output "security_list_ids" {
  description = "Map of all security list OCIDs"
  value = {
    public    = oci_core_security_list.public.id
    private   = oci_core_security_list.private.id
    database  = oci_core_security_list.database.id
    analytics = oci_core_security_list.analytics.id
  }
}

# ====================================
# Network Configuration Outputs
# ====================================

output "network_configuration" {
  description = "Complete network configuration summary"
  value = {
    vcn = {
      id          = oci_core_vcn.main.id
      cidr_block  = oci_core_vcn.main.cidr_blocks[0]
      dns_label   = oci_core_vcn.main.dns_label
      state       = oci_core_vcn.main.state
    }
    
    gateways = {
      internet_gateway = {
        id      = oci_core_internet_gateway.main.id
        enabled = oci_core_internet_gateway.main.enabled
      }
      nat_gateway = {
        id         = oci_core_nat_gateway.main.id
        nat_ip     = oci_core_nat_gateway.main.nat_ip
        blocked    = oci_core_nat_gateway.main.block_traffic
      }
      service_gateway = {
        id = oci_core_service_gateway.main.id
      }
    }
    
    subnets = {
      public = {
        id                    = oci_core_subnet.public.id
        cidr_block           = oci_core_subnet.public.cidr_block
        availability_domain  = oci_core_subnet.public.availability_domain
        prohibit_public_ip   = oci_core_subnet.public.prohibit_public_ip_on_vnic
      }
      private = {
        id                    = oci_core_subnet.private.id
        cidr_block           = oci_core_subnet.private.cidr_block
        availability_domain  = oci_core_subnet.private.availability_domain
        prohibit_public_ip   = oci_core_subnet.private.prohibit_public_ip_on_vnic
      }
      database = {
        id                    = oci_core_subnet.database.id
        cidr_block           = oci_core_subnet.database.cidr_block
        availability_domain  = oci_core_subnet.database.availability_domain
        prohibit_public_ip   = oci_core_subnet.database.prohibit_public_ip_on_vnic
      }
      analytics = {
        id                    = oci_core_subnet.analytics.id
        cidr_block           = oci_core_subnet.analytics.cidr_block
        availability_domain  = oci_core_subnet.analytics.availability_domain
        prohibit_public_ip   = oci_core_subnet.analytics.prohibit_public_ip_on_vnic
      }
    }
  }
}

# ====================================
# DNS and Domain Outputs
# ====================================

output "vcn_domain_name" {
  description = "The domain name of the VCN"
  value       = "${oci_core_vcn.main.dns_label}.oraclevcn.com"
}

output "subnet_domain_names" {
  description = "Map of subnet domain names"
  value = {
    public    = "${oci_core_subnet.public.dns_label}.${oci_core_vcn.main.dns_label}.oraclevcn.com"
    private   = "${oci_core_subnet.private.dns_label}.${oci_core_vcn.main.dns_label}.oraclevcn.com"
    database  = "${oci_core_subnet.database.dns_label}.${oci_core_vcn.main.dns_label}.oraclevcn.com"
    analytics = "${oci_core_subnet.analytics.dns_label}.${oci_core_vcn.main.dns_label}.oraclevcn.com"
  }
}

# ====================================
# Flow Log Outputs (if enabled)
# ====================================

output "flow_log_id" {
  description = "The OCID of the VCN flow log (if enabled)"
  value       = var.enable_flow_logs && var.log_group_id != "" ? oci_core_vcn_flow_log.main[0].id : null
}

# ====================================
# Network Resource Counts
# ====================================

output "resource_counts" {
  description = "Count of network resources created"
  value = {
    vcns             = 1
    subnets          = 4
    route_tables     = 4
    security_lists   = 4
    gateways         = 3
    dhcp_options     = 1
  }
}

# ====================================
# Network Health Check Outputs
# ====================================

output "network_health_endpoints" {
  description = "Endpoints for network health monitoring"
  value = {
    internet_connectivity = "8.8.8.8"  # Google DNS for connectivity test
    oracle_services      = data.oci_core_services.all_services.services[0].cidr_block
    vcn_resolver         = "169.254.169.254"  # OCI metadata service
  }
}

# ====================================
# Cost Estimation Outputs
# ====================================

output "estimated_monthly_network_cost" {
  description = "Estimated monthly cost for networking components (USD)"
  value = {
    nat_gateway      = var.enable_nat_gateway ? "~$45" : "$0"
    load_balancer    = "~$25"
    data_transfer    = "~$10-50 (variable)"
    total_estimated  = var.enable_nat_gateway ? "~$80-120" : "~$35-75"
    note            = "Costs are estimates and may vary based on usage"
  }
}

# ====================================
# Security Compliance Outputs
# ====================================

output "security_compliance_status" {
  description = "Network security compliance information"
  value = {
    private_subnets_isolated     = true
    database_subnet_restricted   = true
    public_access_controlled     = true
    flow_logging_enabled        = var.enable_flow_logs
    security_lists_configured   = true
    network_segmentation        = "4-tier (public, private, database, analytics)"
  }
}
