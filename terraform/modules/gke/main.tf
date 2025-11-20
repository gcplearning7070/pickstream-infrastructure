resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = "${var.region}-a"  # Use zonal cluster instead of regional to reduce quota usage
  
  # Disable deletion protection for dev environment
  deletion_protection = false

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Networking
  network    = var.network_name
  subnetwork = var.subnetwork_name

  # IP allocation policy for VPC-native cluster
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Network policy configuration
  network_policy {
    enabled = true
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Binary Authorization
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Addons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
  }

  # Release channel
  release_channel {
    channel = var.release_channel
  }

  # Master authorized networks (restrict access to control plane)
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  }

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Resource labels
  resource_labels = {
    environment = var.environment
    managed-by  = "terraform"
    application = "pickstream"
  }

  lifecycle {
    ignore_changes = [
      node_pool,
      initial_node_count,
    ]
  }
}

# System node pool for system workloads
resource "google_container_node_pool" "system_pool" {
  name       = "${var.cluster_name}-system-pool"
  location   = "${var.region}-a"
  cluster    = google_container_cluster.primary.name
  node_count = var.system_node_count

  # Autoscaling
  autoscaling {
    min_node_count = var.system_min_nodes
    max_node_count = var.system_max_nodes
  }

  # Node management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Node configuration
  node_config {
    machine_type = var.system_machine_type
    disk_size_gb = 30
    disk_type    = "pd-standard"

    # Service account
    service_account = var.node_service_account
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Labels
    labels = {
      environment = var.environment
      pool-type   = "system"
      managed-by  = "terraform"
    }

    # Taints for system workloads only
    taint {
      key    = "node-pool"
      value  = "system"
      effect = "NO_SCHEDULE"
    }

    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Security
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}

# Application node pool for application workloads
resource "google_container_node_pool" "app_pool" {
  name       = "${var.cluster_name}-app-pool"
  location   = "${var.region}-a"
  cluster    = google_container_cluster.primary.name
  node_count = var.app_node_count

  # Autoscaling
  autoscaling {
    min_node_count = var.app_min_nodes
    max_node_count = var.app_max_nodes
  }

  # Node management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Node configuration
  node_config {
    machine_type = var.app_machine_type
    disk_size_gb = 30
    disk_type    = "pd-standard"

    # Service account
    service_account = var.node_service_account
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Labels
    labels = {
      environment = var.environment
      pool-type   = "application"
      managed-by  = "terraform"
    }

    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Security
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}
