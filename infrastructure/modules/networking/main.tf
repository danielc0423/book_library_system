# ====================================
# Networking Module - Main Configuration
# Oracle Cloud Infrastructure (OCI) 
# Book Library System
# ====================================

# ====================================
# Virtual Cloud Network (VCN)
# ====================================

resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = [var.vcn_cidr]
  dns_label      = var.dns_label
  display_name   = "${var.project_name}-${var.environment}-vcn"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-vcn"
    Type = "networking"
  })
}

# ====================================
# Internet Gateway
# ====================================

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  enabled        = true
  display_name   = "${var.project_name}-${var.environment}-igw"

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-igw"
    Type = "networking"
  })
}

# ====================================
# NAT Gateway
# ====================================

resource "oci_core_nat_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-${var.environment}-nat"
  block_traffic  = false

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat"
    Type = "networking"
  })
}

# ====================================
# Service Gateway
# ====================================

data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

resource "oci_core_service_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-${var.environment}-sgw"

  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-sgw"
    Type = "networking"
  })
}

# ====================================
# DHCP Options
# ====================================

resource "oci_core_dhcp_options" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-${var.environment}-dhcp"

  options {
    type        = "DomainNameServer"
    server_type = "VcnLocalPlusInternet"
  }

  options {
    type                = "SearchDomain"
    search_domain_names = ["${var.dns_label}.oraclevcn.com"]
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-dhcp"
    Type = "networking"
  })
}

# ====================================
# Route Tables
# ====================================

# Public Route Table
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-${var.environment}-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-rt"
    Type = "networking"
  })
}

# Private Route Table
resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-${var.environment}-private-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.main.id
  }

  route_rules {
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.main.id
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-rt"
    Type = "networking"
  })
}

# Database Route Table
resource "oci_core_route_table" "database" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-${var.environment}-db-rt"

  route_rules {
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.main.id
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-rt"
    Type = "networking"
  })
}

# Analytics Route Table
resource "oci_core_route_table" "analytics" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-${var.environment}-analytics-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.main.id
  }

  route_rules {
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.main.id
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-analytics-rt"
    Type = "networking"
  })
}

# ====================================
# Security Lists
# ====================================

# Public Subnet Security List
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-${var.environment}-public-sl"

  # Egress Rules
  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = false
  }

  # Ingress Rules
  # HTTP
  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6" # TCP
    stateless   = false

    tcp_options {
      min = 80
      max = 80
    }
  }

  # HTTPS
  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6" # TCP
    stateless   = false

    tcp_options {
      min = 443
      max = 443
    }
  }

  # SSH
  dynamic "ingress_security_rules" {
    for_each = var.allowed_cidr_blocks
    content {
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"
      protocol    = "6" # TCP
      stateless   = false

      tcp_options {
        min = 22
        max = 22
      }
    }
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-sl"
    Type = "networking"
  })
}

# Private Subnet Security List
resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-${var.environment}-private-sl"

  # Egress Rules
  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = false
  }

  # Ingress Rules
  # All traffic from VCN
  ingress_security_rules {
    source      = var.vcn_cidr
    source_type = "CIDR_BLOCK"
    protocol    = "all"
    stateless   = false
  }

  # SSH from public subnet
  ingress_security_rules {
    source      = var.public_subnet_cidr
    source_type = "CIDR_BLOCK"
    protocol    = "6" # TCP
    stateless   = false

    tcp_options {
      min = 22
      max = 22
    }
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-sl"
    Type = "networking"
  })
}

# Database Subnet Security List
resource "oci_core_security_list" "database" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-${var.environment}-db-sl"

  # Egress Rules
  egress_security_rules {
    destination      = data.oci_core_services.all_services.services[0].cidr_block
    destination_type = "SERVICE_CIDR_BLOCK"
    protocol         = "6" # TCP
    stateless        = false

    tcp_options {
      min = 443
      max = 443
    }
  }

  # Ingress Rules
  # Oracle Database (1521/1522 for TCPS)
  ingress_security_rules {
    source      = var.private_subnet_cidr
    source_type = "CIDR_BLOCK"
    protocol    = "6" # TCP
    stateless   = false

    tcp_options {
      min = 1521
      max = 1522
    }
  }

  # Analytics subnet access
  ingress_security_rules {
    source      = var.analytics_subnet_cidr
    source_type = "CIDR_BLOCK"
    protocol    = "6" # TCP
    stateless   = false

    tcp_options {
      min = 1521
      max = 1522
    }
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-sl"
    Type = "networking"
  })
}

# Analytics Subnet Security List
resource "oci_core_security_list" "analytics" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-${var.environment}-analytics-sl"

  # Egress Rules
  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = false
  }

  # Ingress Rules
  # All traffic from VCN (for internal services)
  ingress_security_rules {
    source      = var.vcn_cidr
    source_type = "CIDR_BLOCK"
    protocol    = "all"
    stateless   = false
  }

  # Analytics Cloud specific ports
  ingress_security_rules {
    source      = var.private_subnet_cidr
    source_type = "CIDR_BLOCK"
    protocol    = "6" # TCP
    stateless   = false

    tcp_options {
      min = 9502
      max = 9502
    }
  }

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-analytics-sl"
    Type = "networking"
  })
}

# ====================================
# Subnets
# ====================================

# Public Subnet
resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = "${var.project_name}-${var.environment}-public-subnet"
  dns_label                  = "public"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  dhcp_options_id            = oci_core_dhcp_options.main.id

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-subnet"
    Type = "networking"
    Tier = "public"
  })
}

# Private Subnet
resource "oci_core_subnet" "private" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.private_subnet_cidr
  display_name               = "${var.project_name}-${var.environment}-private-subnet"
  dns_label                  = "private"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  dhcp_options_id            = oci_core_dhcp_options.main.id

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-subnet"
    Type = "networking"
    Tier = "private"
  })
}

# Database Subnet
resource "oci_core_subnet" "database" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.database_subnet_cidr
  display_name               = "${var.project_name}-${var.environment}-db-subnet"
  dns_label                  = "database"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.database.id
  security_list_ids          = [oci_core_security_list.database.id]
  dhcp_options_id            = oci_core_dhcp_options.main.id

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet"
    Type = "networking"
    Tier = "database"
  })
}

# Analytics Subnet
resource "oci_core_subnet" "analytics" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.analytics_subnet_cidr
  display_name               = "${var.project_name}-${var.environment}-analytics-subnet"
  dns_label                  = "analytics"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.analytics.id
  security_list_ids          = [oci_core_security_list.analytics.id]
  dhcp_options_id            = oci_core_dhcp_options.main.id

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-analytics-subnet"
    Type = "networking"
    Tier = "analytics"
  })
}

# ====================================
# VCN Flow Logs (for monitoring and security)
# ====================================

resource "oci_core_vcn_flow_log" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  log_group_id   = var.log_group_id
  display_name   = "${var.project_name}-${var.environment}-vcn-flow-log"
  is_enabled     = true

  freeform_tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-vcn-flow-log"
    Type = "monitoring"
  })
}
