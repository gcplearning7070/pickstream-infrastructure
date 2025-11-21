# Backend configuration for Terraform state
# Using GCS bucket for state management

terraform {
  backend "gcs" {
    bucket = "gcp-tftbk2"
    prefix = "pickstream-infrastructure/dev/terraform/state"
  }
}
