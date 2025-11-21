# Terraform variables for dev environment
# Project: gcp-terraform-demo-474514

project_id   = "gcp-terraform-478512"
region       = "us-central1"
cluster_name = "pickstream-cluster"
environment  = "dev"

# System node pool configuration
system_node_count  = 1
system_min_nodes   = 1
system_max_nodes   = 3
system_machine_type = "e2-medium"

# Application node pool configuration
app_node_count    = 1
app_min_nodes     = 1
app_max_nodes     = 5
app_machine_type  = "e2-medium"
