output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for the GKE cluster"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "cluster_location" {
  description = "Location of the GKE cluster"
  value       = module.gke.cluster_location
}

output "cluster_region" {
  description = "Region/Zone of the GKE cluster (for backward compatibility)"
  value       = module.gke.cluster_location
}

output "network_name" {
  description = "Name of the VPC network"
  value       = module.networking.network_name
}

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --zone=${module.gke.cluster_location} --project=${var.project_id}"
}

output "workload_identity_service_account" {
  description = "Workload Identity service account email"
  value       = module.iam.workload_identity_service_account_email
}

# Artifact Registry outputs
output "artifact_registry_url" {
  description = "Artifact Registry repository URL"
  value       = module.artifact_registry.repository_url
}

output "artifact_registry_repository_id" {
  description = "Artifact Registry repository ID"
  value       = module.artifact_registry.repository_id
}

output "github_service_account_email" {
  description = "GitHub Actions service account email"
  value       = module.iam.github_service_account_email
}

# Workload Identity - Managed manually
# After cluster creation, create with:
# gcloud iam workload-identity-pools create github-actions-pool --location=global --project=gcp-terraform-demo-474514
# gcloud iam workload-identity-pools providers create-oidc github-actions-provider --location=global --workload-identity-pool=github-actions-pool --issuer-uri="https://token.actions.githubusercontent.com" --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" --attribute-condition="assertion.repository_owner == 'gcpt0801'"
