gcp_project_id   = "<YOUR GOOGLE PROJECT ID>"
cloud            = "EQM"
metal_auth_token = "<YOUR EQUINIX METAL AUTH TOKEN>"
# Change to true if you'd like this terraform to create a new project for you
create_project   = false 
# Only used if you're creating a new project
organization_id  = "<YOUR EQUINIX METAL ORG ID>"
# Only used if you're creating a new project, the name of the new project
project_name     = "cprivitere-anthos-test"
ansible_url      = "https://github.com/cprivitere/ansible-gcpartner-anthos-baremetal/archive/make-eqm-work.tar.gz"
ansible_tar_ball = "make-eqm-work.tar.gz"
gcp_zone          = "<YOUR GCP ZONE>"
metal_metro       = "<YOUR DESIRED EQUINIX METAL METRO>"
metal_cp_plan     = "c3.small.x86"
metal_worker_plan = "m3.large.x86"