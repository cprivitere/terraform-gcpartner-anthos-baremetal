variable "metal_auth_token" {
  type        = string
  description = "Equinix Metal API Key"
}

variable "metal_organization_id" {
  type        = string
  description = "Equinix Metal Organization ID"
}

variable "create_project" {
  type        = bool
  description = "Create a new Project if this is 'true'. Else use provided 'project_id'"
}

variable "project_name" {
  type        = string
  description = "The name of the project if 'create_project' is 'true'."
}

variable "project_id" {
  type        = string
  description = "The project ID to use, if not creating a new one"
}

variable "cp_node_count" {
  type        = number
  description = "How many control plane nodes to deploy"
}

variable "worker_node_count" {
  type        = number
  description = "Total number of nodes to delpoy"
}

variable "metal_cp_plan" {
  type        = string
  description = "Equinix Metal device type to deploy"
}

variable "metal_worker_plan" {
  type        = string
  description = "Equinix Metal device type to deploy"
}

variable "metal_metro" {
  type        = string
  description = "Equinix Metal Facility to deploy into"
}

variable "operating_system" {
  type        = string
  description = "The Operating system of the node"
}

variable "metal_billing_cycle" {
  type        = string
  description = "How the node will be billed (Not usually changed)"
}

variable "cluster_name" {
  type        = string
  description = "The GKE cluster's name"
}

variable "ssh_key" {
  type = object({
    public_key  = string
    private_key = string
  })
}

variable "private_subnet" {
  type        = string
  description = "The private IP space for the cluster"
}

variable "metal_lb_vip_subnet_size" {
  type        = number
  description = "The number of IPs to have for Load Balancer VIPs (2 are used for Control Plane and Ingress VIPs)"
  validation {
    condition     = var.metal_lb_vip_subnet_size > 1
    error_message = "The minimum number of IPs is 2."
  }
}
variable "gcp_project_id" {
  type        = string
  default     = "null"
  description = "The project ID for GCP"
}
variable "gcp_zone" {
  type        = string
  default     = "us-central1-a"
  description = "The GCE zone where the instances should reside"
}

