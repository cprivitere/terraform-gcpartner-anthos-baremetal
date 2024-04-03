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

locals {
  gcp_zone_parts          = split("-", var.gcp_zone)
  gcp_region              = join("-", slice(local.gcp_zone_parts, 0, length(local.gcp_zone_parts) - 1))
  gcp_private_access_cidr = "199.36.153.8/30"

  metal_project_id = var.create_project ? equinix_metal_project.new_project[0].id : var.project_id
  username         = "root"

  // The IPs assigned by Google include a trailing CIDR prefix, but the IPs are not
  // We have to cut off the trailing prefix to get the actual IPs:
  metal_side_ip  = split("/", module.equinix-fabric-connection-gcp.gcp_customer_router_ip_address)[0]
  google_side_ip = split("/", module.equinix-fabric-connection-gcp.gcp_cloud_router_ip_address)[0]

  // And we also have to recompute the CIDR so it specifies the starting IP for the block:
  normalized_cidrhost = cidrhost(module.equinix-fabric-connection-gcp.gcp_customer_router_ip_address, 0)
}

module "equinix-fabric-connection-gcp" {
  source = "/Users/ctreatman/Documents/code/terraform-equinix-fabric-connection-gcp"

  # required variables
  fabric_notification_users     = ["cprivitere@equinix.com"]
  fabric_destination_metro_code = upper(var.metal_metro)
  fabric_speed                  = "50"
  fabric_service_token_id       = equinix_metal_connection.example.service_tokens.0.id

  # gcp_project = var.gcp_project_name // if unspecified, the project configured in the provided block will be used
  gcp_availability_domain = 1


  gcp_gcloud_skip_download = true
  platform                 = "darwin"

  gcp_region = local.gcp_region
  ## BGP config
  gcp_configure_bgp = true
  # gcp_interconnect_customer_asn = // If unspecified, default value "65000" will be used

  # NOTE: name is already known at apply time, so this will not
  # wait for the referenced resource to be created
  gcp_compute_network_id    = google_compute_network.abm.id
  gcp_compute_create_router = false
  gcp_compute_router_id     = google_compute_router.abm.id
}


resource "google_compute_router" "abm" {
  name    = "abm-router"
  network = google_compute_network.abm.name
  region  = local.gcp_region

  bgp {
    asn               = 16550
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
    advertised_ip_ranges {
      range       = local.gcp_private_access_cidr
      description = "private.googleapis.com IPs"
    }
  }
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
  user_data = templatefile("${path.module}/templates/configure_ips.sh.tmpl", {
    vlan                    = equinix_metal_vlan.vlan1.vxlan,
    machine_cidr            = equinix_metal_reserved_ip_block.example.cidr_notation,
    netmask                 = equinix_metal_reserved_ip_block.example.netmask,
    gateway_ip              = cidrhost(equinix_metal_reserved_ip_block.example.cidr_notation, 1),
    machine_ip              = cidrhost(equinix_metal_reserved_ip_block.example.cidr_notation, count.index + 2),
    gcp_network_cidr        = data.google_compute_subnetwork.abm.ip_cidr_range,
    gcp_private_access_cidr = local.gcp_private_access_cidr
    gcp_dns_forwarder_ip    = data.google_compute_addresses.dns_query_forwarder.addresses[0].address
  })
  ip_address {
    type = "private_ipv4"
    cidr = 31
  }
  ip_address {
    type = "public_ipv4"
  }
}

resource "equinix_metal_device_network_type" "cp_node" {
  count     = var.cp_node_count
  device_id = equinix_metal_device.cp_node[count.index].id
  type      = "hybrid"
}

resource "equinix_metal_port_vlan_attachment" "cp_node" {
  count     = var.cp_node_count
  device_id = equinix_metal_device_network_type.cp_node[count.index].id
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
  user_data = templatefile("${path.module}/templates/configure_ips.sh.tmpl", {
    vlan                    = equinix_metal_vlan.vlan1.vxlan,
    machine_cidr            = equinix_metal_reserved_ip_block.example.cidr_notation,
    netmask                 = equinix_metal_reserved_ip_block.example.netmask,
    gateway_ip              = cidrhost(equinix_metal_reserved_ip_block.example.cidr_notation, 1),
    machine_ip              = cidrhost(equinix_metal_reserved_ip_block.example.cidr_notation, count.index + var.cp_node_count + 2),
    gcp_network_cidr        = data.google_compute_subnetwork.abm.ip_cidr_range,
    gcp_private_access_cidr = local.gcp_private_access_cidr
    gcp_dns_forwarder_ip    = data.google_compute_addresses.dns_query_forwarder.addresses[0].address
  })
  ip_address {
    type = "private_ipv4"
    cidr = 29
  }
  ip_address {
    type = "public_ipv4"
  }
}

resource "equinix_metal_device_network_type" "worker_node" {
  count     = var.worker_node_count
  device_id = equinix_metal_device.worker_node[count.index].id
  type      = "hybrid"
}

resource "equinix_metal_port_vlan_attachment" "worker_node" {
  count     = var.worker_node_count
  device_id = equinix_metal_device_network_type.worker_node[count.index].id
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
  description = "VRF with ASN 65000 and a pool of address space that includes 192.168.100.0/28"
  name        = "example-vrf"
  metro       = var.metal_metro
  local_asn   = "65000"
  ip_ranges   = ["192.168.100.0/28"]
  project_id  = local.metal_project_id

  # Since we have to jam in the Google-provided IP range with a restapi resource,
  # we have to ignore changes to IP ranges in the resource itself
  #lifecycle {
  #  ignore_changes = [ip_ranges]
  #}
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
}

resource "restapi_object" "vrf_metal_to_gcp_ip_range" {
  path = "/vrfs/${equinix_metal_vrf.example.id}"

  create_method = "PUT"

  data = jsonencode({
    ip_ranges = setunion(equinix_metal_vrf.example.ip_ranges, ["${local.normalized_cidrhost}/29"])
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
    subnet      = "${local.normalized_cidrhost}/30"
  })
}

resource "google_compute_network" "abm" {
  name = "abm-network"
}

data "google_compute_subnetwork" "abm" {
  name   = google_compute_network.abm.name
  region = local.gcp_region
}

resource "google_dns_managed_zone" "private-zone" {
  name        = "private-zone"
  dns_name    = "googleapis.com."
  description = "DNS zone for Google Private Access"

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.abm.id
    }
  }
}

resource "google_dns_record_set" "a" {
  name         = "private.${google_dns_managed_zone.private-zone.dns_name}"
  managed_zone = google_dns_managed_zone.private-zone.name
  type         = "A"
  ttl          = 300

  rrdatas = ["199.36.153.8", "199.36.153.9", "199.36.153.10", "199.36.153.11"]
}

resource "google_dns_record_set" "cname" {
  name         = "*.${google_dns_managed_zone.private-zone.dns_name}"
  managed_zone = google_dns_managed_zone.private-zone.name
  type         = "CNAME"
  ttl          = 300

  rrdatas = ["private.${google_dns_managed_zone.private-zone.dns_name}"]
}

resource "google_dns_policy" "inbound_dns" {
  name                      = "inbound-dns-policy"
  enable_inbound_forwarding = true

  networks {
    network_url = google_compute_network.abm.id
  }
}

data "google_compute_addresses" "dns_query_forwarder" {
  filter     = "name:dns-forwarding-*"
  region     = local.gcp_region
  depends_on = [google_dns_policy.inbound_dns]
}
