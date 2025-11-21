variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region for resources"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "pickstream-cluster"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# System node pool variables
variable "system_node_count" {
  description = "Initial number of nodes in system pool"
  type        = number
  default     = 2
}

variable "system_min_nodes" {
  description = "Minimum number of nodes in system pool"
  type        = number
  default     = 1
}

variable "system_max_nodes" {
  description = "Maximum number of nodes in system pool"
  type        = number
  default     = 3
}

variable "system_machine_type" {
  description = "Machine type for system node pool"
  type        = string
  default     = "e2-medium"
}

# Application node pool variables
variable "app_node_count" {
  description = "Initial number of nodes in application pool"
  type        = number
  default     = 3
}

variable "app_min_nodes" {
  description = "Minimum number of nodes in application pool"
  type        = number
  default     = 2
}

variable "app_max_nodes" {
  description = "Maximum number of nodes in application pool"
  type        = number
  default     = 5
}

variable "app_machine_type" {
  description = "Machine type for application node pool"
  type        = string
  default     = "e2-standard-2"
}

# GitHub variables - Not needed since Workload Identity is managed manually
# variable "github_repository" {
#   description = "GitHub repository for Workload Identity (owner/repo)"
#   type        = string
#   default     = "gcpt0801/pickstream-app"
# }
#
# variable "github_org" {
#   description = "GitHub organization/owner"
#   type        = string
#   default     = "gcpt0801"
# }
