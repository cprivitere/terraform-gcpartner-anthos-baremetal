terraform {
  required_providers {
    equinix = {
      source = "equinix/equinix"
    }
  }
}

module "equinix-fabric-connection-gcp" {
  source = "/home/cprivitere/cprivitere-stuff/terraform-equinix-fabric-connection-gcp"
  #version = "0.3.0"

  # required variables
  fabric_notification_users     = ["cprivitere@equinix.com"]
  fabric_destination_metro_code = upper(var.metal_metro)
  fabric_speed                  = "50"
  fabric_service_token_id       = equinix_metal_connection.example.service_tokens.0.id

  # gcp_project = var.gcp_project_name // if unspecified, the project configured in the provided block will be used
  gcp_availability_domain = 1

  gcp_gcloud_skip_download = true
  platform                 = "linux"

  gcp_region = "us-east4"
  ## BGP config
  gcp_configure_bgp = true
  # gcp_interconnect_customer_asn = // If unspecified, default value "65000" will be used
}

resource "equinix_metal_project" "new_project" {
  count           = var.create_project ? 1 : 0
  name            = var.project_name
  organization_id = var.metal_organization_id
  bgp_config {
    deployment_type = "local"
    asn             = 65000
  }
}

locals {
  metal_project_id = var.create_project ? equinix_metal_project.new_project[0].id : var.project_id
  username         = "root"
}

resource "equinix_metal_project_ssh_key" "ssh_pub_key" {
  name       = var.cluster_name
  public_key = var.ssh_key.public_key
  project_id = local.metal_project_id
}

resource "equinix_metal_device" "cp_node" {
  depends_on = [
    equinix_metal_project_ssh_key.ssh_pub_key
  ]
  count            = var.cp_node_count
  hostname         = format("%s-cp-%02d", var.cluster_name, count.index + 1)
  plan             = var.metal_worker_plan
  metro            = var.metal_metro
  operating_system = var.operating_system
  billing_cycle    = var.metal_billing_cycle
  project_id       = local.metal_project_id
  tags             = ["anthos", "baremetal"]
  ip_address {
    type = "private_ipv4"
    cidr = 31
  }
  ip_address {
    type = "public_ipv4"
  }
}

resource "equinix_metal_device" "worker_node" {
  depends_on = [
    equinix_metal_project_ssh_key.ssh_pub_key
  ]
  count            = var.worker_node_count
  hostname         = format("%s-worker-%02d", var.cluster_name, count.index + 1)
  plan             = var.metal_worker_plan
  metro            = var.metal_metro
  operating_system = var.operating_system
  billing_cycle    = var.metal_billing_cycle
  project_id       = local.metal_project_id
  tags             = ["anthos", "baremetal"]
  ip_address {
    type = "private_ipv4"
    cidr = 29
  }
  ip_address {
    type = "public_ipv4"
  }
}

resource "equinix_metal_bgp_session" "enable_cp_bgp" {
  count          = var.cp_node_count
  device_id      = element(equinix_metal_device.cp_node.*.id, count.index)
  address_family = "ipv4"
}

resource "equinix_metal_bgp_session" "enable_worker_bgp" {
  count          = var.worker_node_count
  device_id      = element(equinix_metal_device.worker_node.*.id, count.index)
  address_family = "ipv4"
}

resource "equinix_metal_reserved_ip_block" "lb_vip_subnet" {
  project_id  = local.metal_project_id
  type        = "public_ipv4"
  metro       = var.metal_metro
  quantity    = var.metal_lb_vip_subnet_size
  description = "${var.cluster_name}: Load Balancer VIPs 01"
  tags        = ["cluster:${var.cluster_name}", "created_by:terraform", "created_at:${timestamp()}"]
}

# Create a new VLAN in metro "esv"
resource "equinix_metal_vlan" "vlan1" {
  description = "Gcloud VLAN"
  metro       = var.metal_metro
  project_id  = local.metal_project_id
  vxlan       = 1040
}

resource "equinix_metal_vrf" "example" {
  description = "VRF with ASN 65000 and a pool of address space that includes 192.168.100.0/25"
  name        = "example-vrf"
  metro       = var.metal_metro
  local_asn   = "65000"
  ip_ranges   = ["192.168.100.0/25", "192.168.200.0/25", "169.254.140.64/29"]
  project_id  = local.metal_project_id
}
resource "equinix_metal_reserved_ip_block" "example" {
  description = "Reserved IP block (192.168.100.0/29) taken from on of the ranges in the VRF's pool of address space."
  project_id  = local.metal_project_id
  metro       = var.metal_metro
  type        = "vrf"
  vrf_id      = equinix_metal_vrf.example.id
  cidr        = 29
  network     = "192.168.100.0"
}

resource "equinix_metal_gateway" "example" {
  project_id        = local.metal_project_id
  vlan_id           = equinix_metal_vlan.vlan1.id
  ip_reservation_id = equinix_metal_reserved_ip_block.example.id
}


resource "equinix_metal_connection" "example" {
  name               = "tf-metal-to-google"
  project_id         = local.metal_project_id
  type               = "shared"
  redundancy         = "primary"
  metro              = var.metal_metro
  speed              = "50Mbps"
  service_token_type = "a_side"
  vrfs               = [equinix_metal_vrf.example.id]
}
