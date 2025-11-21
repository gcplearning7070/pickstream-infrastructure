terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# IAM Module
module "iam" {
  source = "../../modules/iam"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  environment  = var.environment
}

# Networking Module
module "networking" {
  source = "../../modules/networking"

  project_id   = var.project_id
  region       = var.region
  network_name = "${var.cluster_name}-network"
  environment  = var.environment
}

# GKE Module
module "gke" {
  source = "../../modules/gke"

  project_id          = var.project_id
  region              = var.region
  cluster_name        = var.cluster_name
  environment         = var.environment
  network_name        = module.networking.network_name
  subnetwork_name     = module.networking.subnetwork_name
  node_service_account = module.iam.node_service_account_email

  # System node pool configuration
  system_node_count  = var.system_node_count
  system_min_nodes   = var.system_min_nodes
  system_max_nodes   = var.system_max_nodes
  system_machine_type = var.system_machine_type

  # Application node pool configuration
  app_node_count    = var.app_node_count
  app_min_nodes     = var.app_min_nodes
  app_max_nodes     = var.app_max_nodes
  app_machine_type  = var.app_machine_type

  depends_on = [
    module.networking,
    module.iam
  ]
}

# Artifact Registry Module
module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id                = var.project_id
  location                  = var.region
  repository_id             = "pickstream"
  gke_node_service_account  = module.iam.node_service_account_email
  github_service_account    = module.iam.github_service_account_email

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  depends_on = [
    module.iam
  ]
}

# Workload Identity Federation Module - Managed manually outside Terraform
# Create manually with:
# gcloud iam workload-identity-pools create github-actions-pool --location=global --project=gcp-terraform-demo-474514
# gcloud iam workload-identity-pools providers create-oidc github-actions-provider --location=global --workload-identity-pool=github-actions-pool --issuer-uri="https://token.actions.githubusercontent.com" --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" --attribute-condition="assertion.repository_owner == 'gcpt0801'"

# module "workload_identity" {
#   source = "../../modules/workload-identity"
#
#   project_id            = var.project_id
#   github_repository     = var.github_repository
#   service_account_name  = module.iam.github_service_account_name
#   attribute_condition   = "assertion.repository_owner == '${var.github_org}'"
#
#   depends_on = [
#     module.iam
#   ]
# }
