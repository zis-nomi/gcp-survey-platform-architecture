resource "google_compute_network" "main" {
  name                    = var.name
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  depends_on              = [google_project_service.required]
}
resource "google_compute_subnetwork" "gke" {
  name                     = "${var.name}-gke"
  region                   = var.region
  network                  = google_compute_network.main.id
  ip_cidr_range            = "10.40.0.0/20"
  private_ip_google_access = true
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.44.0.0/16"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.48.0.0/20"
  }
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.1
    metadata             = "INCLUDE_ALL_METADATA"
  }
}
resource "google_compute_router" "main" {
  name    = var.name
  region  = var.region
  network = google_compute_network.main.id
}
resource "google_compute_router_nat" "egress" {
  name                               = "${var.name}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.gke.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
resource "google_compute_global_address" "sql" {
  name          = "${var.name}-sql-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = "10.50.0.0"
  prefix_length = 16
  network       = google_compute_network.main.id
}
resource "google_service_networking_connection" "sql" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.sql.name]
  depends_on              = [google_project_service.required]
}
