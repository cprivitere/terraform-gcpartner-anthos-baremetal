[![Anthos on Baremetal Website](https://img.shields.io/badge/Website-cloud.google.com/anthos-blue)](https://cloud.google.com/anthos) [![Apache License](https://img.shields.io/github/license/GCPartner/phoenixnap-megaport-anthos)](https://github.com/GCPartner/terraform-gcpartner-anthos-baremetal/blob/main/LICENSE) [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](https://github.com/GCPartner/terraform-gcpartner-anthos-baremetal/pulls) ![](https://img.shields.io/badge/Stability-Experimental-red.svg)

# Google Anthos on Baremetal

This [Terraform](http://terraform.io) module will allow you to deploy [Google Cloud's Anthos on Baremetal](https://cloud.google.com/anthos) on Multiple different Clouds (Google Cloud, PhoenixNAP, & Equinix Metal)

The software in this repository has been tested sucessfully on the following hosts:

1. Ubuntu 20.04 (amd64)
1. macOS 12.4 (macOS Catalina with an Intel processor)

## Prerequisites

### Software to Install

- [gcloud command line](https://cloud.google.com/sdk/docs/install)
- [terraform](https://www.terraform.io/downloads)
- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [jq](https://stedolan.github.io/jq/download/)

### Accounts Needed

- [Google Cloud Account](https://console.cloud.google.com/)
- If Cloud == PNAP
  - [PhoenixNAP](https://phoenixnap.com/bare-metal-cloud)
- If Cloud == EQM
  - [Equinix Metal](https://metal.equinix.com)

### Information to Gather

- Deploy on GCP
  - Your GCP Project ID
- Deploy on PhoenixNAP
  - Client ID
  - Client Secret
- Deploy on Equinix Metal
  - API Auth Token
  - Your Equinix Metal Project ID

## Deployment

### Authenticate to Google Cloud

```bash
gcloud init # Follow any prompts
gcloud auth application-default login # Follown any prompts
```

### Clone the Repo

```bash
git clone https://github.com/GCPartner/terraform-gcpartner-anthos-baremetal.git
cd terraform-gcpartner-anthos-baremetal
```

### Create your _terraform.tfvars_

The following values will need to be modified by you.

#### GCP Minimal Deployment

```bash
cat <<EOF >terraform.tfvars
gcp_project_id = "my_project"
EOF
```

#### PhoenixNAP Minimal Deployment

```bash
cat <<EOF >terraform.tfvars
gcp_project_id = "my_project"
cloud = "PNAP"
pnap_client_id = "******"
pnap_client_secret = "******"
pnap_network_name = "my-network"
EOF
```

#### Equinix Metal Minimal Deployment

```bash
cat <<EOF >terraform.tfvars
gcp_project_id = "my_project"
cloud = "EQM"
metal_auth_token = "a0ec413e-0786-4c17-a302-20ccd8a40c2e"
metal_project_id = "cf27282f-df35-4839-9f15-77e201aa2a2c"
EOF
```

### Initialize Terraform

```bash
terraform init
```

### Deploy the stack

```bash
terraform apply --auto-approve
```

### What success looks like

```
Apply complete! Resources: 79 added, 0 changed, 0 destroyed.

Outputs:

bastion_host_ip = "34.134.208.244"
bastion_host_username = "gcp"
private_subnet = "172.31.254.0/24"
ssh_command = "ssh -i /home/c0dyhi11/.ssh/anthos-cody-qp5we gcp@34.134.208.244"
ssh_key_path = "/home/c0dyhi11/.ssh/anthos-cody-qp5we"
vlan_id = "Not applicable for Google cloud"
```

How to get the kubeconfig file:

```
terraform output kubeconfig | grep -v EOT > kubeconfig
```

<!-- BEGIN_TF_DOCS -->

## Inputs

| Name                                                                                                      | Description                                                                                                       | Type     | Default                                                                                             | Required |
| --------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | -------- | --------------------------------------------------------------------------------------------------- | :------: |
| <a name="input_cloud"></a> [cloud](#input_cloud)                                                          | GCP (Google Cloud Platform), EQM (Equinx Metal), or PNAP (Phoenix Nap) to deploy the 'Nodes'                      | `string` | `"GCP"`                                                                                             |    no    |
| <a name="input_organization_id"></a> [organization_id](#input_organization_id)                            | Organization ID (GCP or EQM)                                                                                      | `string` | `"null"`                                                                                            |    no    |
| <a name="input_operating_system"></a> [operating_system](#input_operating_system)                         | The Operating system to deploy (Only ubuntu_20_04 has been tested)                                                | `string` | `"ubuntu_20_04"`                                                                                    |    no    |
| <a name="input_cluster_name"></a> [cluster_name](#input_cluster_name)                                     | The ABM cluster name                                                                                              | `string` | `"abm-cluster"`                                                                                     |    no    |
| <a name="input_create_project"></a> [create_project](#input_create_project)                               | Create a new Project if this is 'true'. Else use provided 'project_id' (Unsuported for PNAP)                      | `bool`   | `false`                                                                                             |    no    |
| <a name="input_project_name"></a> [project_name](#input_project_name)                                     | The name of the project if 'create_project' is 'true'.                                                            | `string` | `"abm-lab"`                                                                                         |    no    |
| <a name="input_private_subnet"></a> [private_subnet](#input_private_subnet)                               | The private IP space for the cluster                                                                              | `string` | `"172.31.254.0/24"`                                                                                 |    no    |
| <a name="input_ha_control_plane"></a> [ha_control_plane](#input_ha_control_plane)                         | Do you want a highly available control plane                                                                      | `bool`   | `true`                                                                                              |    no    |
| <a name="input_worker_node_count"></a> [worker_node_count](#input_worker_node_count)                      | How many worker nodes to deploy                                                                                   | `number` | `3`                                                                                                 |    no    |
| <a name="input_network_type"></a> [network_type](#input_network_type)                                     | Deploy the nodes on a 'private' or 'public' network. (Only supported in PNAP today).                              | `string` | `"public"`                                                                                          |    no    |
| <a name="input_create_network"></a> [create_network](#input_create_network)                               | Create a new network if this is 'true'. Else use provided 'p\*\_network_id'                                       | `bool`   | `true`                                                                                              |    no    |
| <a name="input_public_network_id"></a> [public_network_id](#input_public_network_id)                      | If create_network=false, this will be the public network used for the deployment. (Only supported in PNAP today)  | `string` | `"null"`                                                                                            |    no    |
| <a name="input_private_network_id"></a> [private_network_id](#input_private_network_id)                   | If create_network=false, this will be the private network used for the deployment. (Only supported in PNAP today) | `string` | `"null"`                                                                                            |    no    |
| <a name="input_ansible_playbook_version"></a> [ansible_playbook_version](#input_ansible_playbook_version) | The version of the ansible playbook to install                                                                    | `string` | `"v1.14.2-001"`                                                                                     |    no    |
| <a name="input_ansible_url"></a> [ansible_url](#input_ansible_url)                                        | URL of the ansible code                                                                                           | `string` | `"https://github.com/GCPartner/ansible-gcpartner-anthos-baremetal/archive/refs/tags/v1.0.3.tar.gz"` |    no    |
| <a name="input_ansible_tar_ball"></a> [ansible_tar_ball](#input_ansible_tar_ball)                         | Tarball of the ansible code                                                                                       | `string` | `"v1.0.3.tar.gz"`                                                                                   |    no    |
| <a name="input_pnap_client_id"></a> [pnap_client_id](#input_pnap_client_id)                               | PhoenixNAP API ID                                                                                                 | `string` | `"null"`                                                                                            |    no    |
| <a name="input_pnap_client_secret"></a> [pnap_client_secret](#input_pnap_client_secret)                   | PhoenixNAP API Secret                                                                                             | `string` | `"null"`                                                                                            |    no    |
| <a name="input_pnap_location"></a> [pnap_location](#input_pnap_location)                                  | PhoenixNAP Location to deploy into                                                                                | `string` | `"ASH"`                                                                                             |    no    |
| <a name="input_pnap_cp_type"></a> [pnap_cp_type](#input_pnap_cp_type)                                     | PhoenixNAP server type to deploy for control plane nodes                                                          | `string` | `"s2.c1.medium"`                                                                                    |    no    |
| <a name="input_pnap_worker_type"></a> [pnap_worker_type](#input_pnap_worker_type)                         | PhoenixNAP server type to deploy for worker nodes                                                                 | `string` | `"s2.c1.medium"`                                                                                    |    no    |
| <a name="input_gcp_project_id"></a> [gcp_project_id](#input_gcp_project_id)                               | The project ID for GCP                                                                                            | `string` | `"null"`                                                                                            |    no    |
| <a name="input_gcp_cp_instance_type"></a> [gcp_cp_instance_type](#input_gcp_cp_instance_type)             | The GCE instance type for control plane nodes                                                                     | `string` | `"e2-standard-8"`                                                                                   |    no    |
| <a name="input_gcp_worker_instance_type"></a> [gcp_worker_instance_type](#input_gcp_worker_instance_type) | The GCE instance type for worker nodes                                                                            | `string` | `"e2-standard-8"`                                                                                   |    no    |
| <a name="input_gcp_zone"></a> [gcp_zone](#input_gcp_zone)                                                 | The GCE zone where the instances should reside                                                                    | `string` | `"us-central1-a"`                                                                                   |    no    |
| <a name="input_gcp_billing_account"></a> [gcp_billing_account](#input_gcp_billing_account)                | The GCP billing account to use for the project                                                                    | `string` | `"null"`                                                                                            |    no    |
| <a name="input_metal_auth_token"></a> [metal_auth_token](#input_metal_auth_token)                         | Equinix Metal API Key                                                                                             | `string` | `"null"`                                                                                            |    no    |
| <a name="input_metal_project_id"></a> [metal_project_id](#input_metal_project_id)                         | The project ID to use for EQM                                                                                     | `string` | `"null"`                                                                                            |    no    |
| <a name="input_metal_metro"></a> [metal_metro](#input_metal_metro)                                        | Equinix Metal Facility to deploy into                                                                             | `string` | `"ny"`                                                                                              |    no    |
| <a name="input_metal_cp_plan"></a> [metal_cp_plan](#input_metal_cp_plan)                                  | Equinix Metal device type to deploy for cp nodes                                                                  | `string` | `"c3.small.x86"`                                                                                    |    no    |
| <a name="input_metal_worker_plan"></a> [metal_worker_plan](#input_metal_worker_plan)                      | Equinix Metal device type to deploy for worker nodes                                                              | `string` | `"c3.small.x86"`                                                                                    |    no    |
| <a name="input_metal_billing_cycle"></a> [metal_billing_cycle](#input_metal_billing_cycle)                | How the node will be billed (Not usually changed)                                                                 | `string` | `"hourly"`                                                                                          |    no    |
| <a name="input_metal_lb_vip_subnet_size"></a> [metal_lb_vip_subnet_size](#input_metal_lb_vip_subnet_size) | The number of IPs to have for Load Balancer VIPs (2 are used for Control Plane and Ingress VIPs)                  | `number` | `8`                                                                                                 |    no    |

## Outputs

| Name                                                                                               | Description                                            |
| -------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| <a name="output_ssh_command"></a> [ssh_command](#output_ssh_command)                               | Command to run to SSH into the bastion host            |
| <a name="output_ssh_key_path"></a> [ssh_key_path](#output_ssh_key_path)                            | Path to the SSH Private key for the bastion host       |
| <a name="output_bastion_host_ip"></a> [bastion_host_ip](#output_bastion_host_ip)                   | IP Address of the bastion host in the test environment |
| <a name="output_bastion_host_username"></a> [bastion_host_username](#output_bastion_host_username) | Username for the bastion host in the test environment  |
| <a name="output_vlan_id"></a> [vlan_id](#output_vlan_id)                                           | The vLan ID for the server network                     |
| <a name="output_subnet"></a> [subnet](#output_subnet)                                              | The IP space for the cluster                           |
| <a name="output_cluster_name"></a> [cluster_name](#output_cluster_name)                            | The name of the Anthos Cluster                         |
| <a name="output_kubeconfig"></a> [kubeconfig](#output_kubeconfig)                                  | The kubeconfig for the Anthos Cluster                  |
| <a name="output_ssh_key"></a> [ssh_key](#output_ssh_key)                                           | SSH Public and Private Key                             |
| <a name="output_network_details"></a> [network_details](#output_network_details)                   | The network details for the nodes                      |
| <a name="output_os_image"></a> [os_image](#output_os_image)                                        | The OS Image used to build the nodes                   |

<!-- END_TF_DOCS -->
