terraform {
  required_providers {
    equinix = {
      source = "equinix/equinix"
    }
    restapi = {
      source = "Mastercard/restapi"
    }
  }
}

module "equinix-fabric-connection-gcp" {
  source = "github.com/equinix-labs/terraform-equinix-fabric-connection-gcp?ref=cprivitere-patch-outputs"

  # required variables
  fabric_notification_users     = ["cprivitere@equinix.com"]
  fabric_destination_metro_code = upper(var.metal_metro)
  fabric_speed                  = "50"
  fabric_service_token_id       = equinix_metal_connection.example.service_tokens.0.id

  # gcp_project = var.gcp_project_name // if unspecified, the project configured in the provided block will be used
  gcp_availability_domain = 1

  gcp_gcloud_skip_download = true
  platform                 = "darwin"

  gcp_region = trim(var.gcp_zone, "-a")
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

resource "equinix_metal_port_vlan_attachment" "cp_node" {
  count     = var.cp_node_count
  device_id = equinix_metal_device.cp_node[count.index].id
  vlan_vnid = equinix_metal_vlan.vlan1.vxlan
  port_name = "eth1"
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

resource "equinix_metal_port_vlan_attachment" "worker_node" {
  count     = var.worker_node_count
  device_id = equinix_metal_device.worker_node[count.index].id
  vlan_vnid = equinix_metal_vlan.vlan1.vxlan
  port_name = "eth1"
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
  # TODO: 169.254.... address should be read from somewhere instead of hard-coded? But that leads to a cycle
  #ip_ranges   = ["192.168.100.0/25", "192.168.200.0/25", "169.254.140.64/29", module.equinix-fabric-connection-gcp.gcp_customer_router_ip_address]
  ip_ranges  = ["192.168.100.0/25", "192.168.200.0/25", "169.254.140.64/29"]
  project_id = local.metal_project_id

  # Since we have to jam in the Google-provided IP range with a restapi resource,
  # we have to ignore changes to IP ranges in the resource itself
  lifecycle {
    ignore_changes = [ip_ranges]
  }
}
resource "equinix_metal_reserved_ip_block" "example" {
  description = "Reserved IP block (192.168.100.0/28) taken from on of the ranges in the VRF's pool of address space."
  project_id  = local.metal_project_id
  metro       = var.metal_metro
  type        = "vrf"
  vrf_id      = equinix_metal_vrf.example.id
  cidr        = 28
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
  # TODO: update BGP peer settings on hidden shared connection VC
}

locals {
  metal_side_ip  = split("/", module.equinix-fabric-connection-gcp.gcp_customer_router_ip_address)[0]
  google_side_ip = split("/", module.equinix-fabric-connection-gcp.gcp_cloud_router_ip_address)[0]

  // I think this should be fairly safe because these IPs are automatically
  // assigned by Google and appear to match until the last octet
  lowest_ip = sort([local.metal_side_ip, local.google_side_ip])[0]
}

resource "restapi_object" "vrf_metal_to_gcp_ip_range" {
  path = "/vrfs/${equinix_metal_vrf.example.id}"

  create_method = "PUT"

  data = jsonencode({
    ip_ranges = setunion(equinix_metal_vrf.example.ip_ranges, ["${local.lowest_ip}/29"])
  })
}

resource "restapi_object" "vrf_vc_bgp_peering" {
  depends_on = [restapi_object.vrf_metal_to_gcp_ip_range]
  # We made a non-redundant connection so we can assume there's one port with one VC
  path = "/virtual-circuits/${equinix_metal_connection.example.ports[0].virtual_circuit_ids[0]}"

  # Virtual Circuits on a shared connection are API-managed,
  # so we want to `PUT` an update to the existing circuit
  # even  though we're "creating" the resource from the
  # terraform point-of-view
  create_method = "PUT"

  # TODO
  data = jsonencode({
    customer_ip = local.google_side_ip
    metal_ip    = local.metal_side_ip
    peer_asn    = 16550
    subnet      = "${local.lowest_ip}/30"
  })
}
