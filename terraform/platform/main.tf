locals {
  services = toset([
    "compute.googleapis.com", "container.googleapis.com", "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com", "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com", "iam.googleapis.com", "iamcredentials.googleapis.com",
    "logging.googleapis.com", "monitoring.googleapis.com", "storage.googleapis.com",
  ])
  workloads = toset(["api", "worker"])
}
resource "google_project_service" "required" {
  for_each           = local.services
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
