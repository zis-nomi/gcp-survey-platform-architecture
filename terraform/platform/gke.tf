resource "google_container_cluster" "main" {
  name                     = var.name
  location                 = var.region
  node_locations           = var.node_zones
  network                  = google_compute_network.main.id
  subnetwork               = google_compute_subnetwork.gke.id
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = var.deletion_protection
  networking_mode          = "VPC_NATIVE"
  datapath_provider        = "ADVANCED_DATAPATH"
  enable_shielded_nodes    = true
  resource_labels          = var.labels
  release_channel {
    channel = "REGULAR"
  }
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "172.20.0.0/28"
    master_global_access_config {
      enabled = true
    }
  }
  master_authorized_networks_config {
    private_endpoint_enforcement_enabled = true
    cidr_blocks {
      cidr_block   = google_compute_subnetwork.gke.ip_cidr_range
      display_name = "gke-subnet"
    }
    dynamic "cidr_blocks" {
      for_each = var.admin_cidrs
      content {
        cidr_block   = cidr_blocks.value
        display_name = cidr_blocks.key
      }
    }
  }
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }
  # Also secure the temporary default pool used during cluster creation.
  node_config {
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
  depends_on = [google_project_iam_member.node_system, google_compute_router_nat.egress]
}
resource "google_container_node_pool" "main" {
  name           = "general"
  cluster        = google_container_cluster.main.name
  location       = var.region
  node_locations = var.node_zones
  # Initial count is per zone; autoscaler bounds below are totals.
  initial_node_count = 1
  autoscaling {
    total_min_node_count = var.min_nodes
    total_max_node_count = var.max_nodes
    # Best-effort distribution of scale-up capacity across the selected zones.
    location_policy = "BALANCED"
  }
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
  node_config {
    machine_type    = var.node_machine_type
    disk_size_gb    = 50
    disk_type       = "pd-balanced"
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    labels          = var.labels
    metadata = {
      disable-legacy-endpoints = "true"
    }
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
  lifecycle {
    precondition {
      condition     = alltrue([for zone in var.node_zones : startswith(zone, "${var.region}-")]) && var.max_nodes >= length(var.node_zones)
      error_message = "Worker zones must be in the selected region, and max_nodes must cover the initial one node per zone."
    }
  }
  depends_on = [google_artifact_registry_repository_iam_member.node_reader]
}
