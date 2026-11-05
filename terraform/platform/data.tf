resource "google_sql_database_instance" "main" {
  name                = "${var.name}-postgres"
  region              = var.region
  database_version    = "POSTGRES_16"
  deletion_protection = var.deletion_protection
  settings {
    tier                        = var.sql_tier
    edition                     = "ENTERPRISE"
    availability_type           = var.sql_ha ? "REGIONAL" : "ZONAL"
    disk_type                   = "PD_SSD"
    disk_size                   = 20
    disk_autoresize             = true
    disk_autoresize_limit       = 100
    deletion_protection_enabled = var.deletion_protection
    user_labels                 = var.labels
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.main.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
    backup_configuration {
      enabled                        = true
      start_time                     = "02:00"
      location                       = var.region
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }
    maintenance_window {
      day          = 7
      hour         = 3
      update_track = "stable"
    }
  }
  depends_on = [google_service_networking_connection.sql]
}
resource "google_sql_database" "app" {
  name     = "assessment"
  instance = google_sql_database_instance.main.name
}
resource "google_sql_user" "workload" {
  for_each = local.workloads
  name     = trimsuffix(google_service_account.workload[each.key].email, ".gserviceaccount.com")
  instance = google_sql_database_instance.main.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}
resource "google_storage_bucket" "files" {
  name                        = "${var.project_id}-${var.name}-files"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = var.labels
  versioning {
    enabled = true
  }
  soft_delete_policy {
    retention_duration_seconds = 604800
  }
  depends_on = [google_project_service.required]
}
resource "google_storage_bucket_iam_member" "api_files" {
  for_each = toset(["roles/storage.objectCreator", "roles/storage.objectViewer"])
  bucket   = google_storage_bucket.files.name
  role     = each.value
  member   = "serviceAccount:${google_service_account.workload["api"].email}"
}
resource "google_storage_bucket_iam_member" "worker_files" {
  bucket = google_storage_bucket.files.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.workload["worker"].email}"
}
resource "google_artifact_registry_repository" "images" {
  location      = var.region
  repository_id = "${var.name}-images"
  format        = "DOCKER"
  labels        = var.labels
  docker_config {
    immutable_tags = true
  }
  depends_on = [google_project_service.required]
}
resource "google_artifact_registry_repository_iam_member" "node_reader" {
  location   = var.region
  repository = google_artifact_registry_repository.images.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.nodes.email}"
}
resource "google_secret_manager_secret" "integration" {
  secret_id = "${var.name}-integration-token"
  labels    = var.labels
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  depends_on = [google_project_service.required]
}
resource "google_secret_manager_secret_iam_member" "api_access" {
  secret_id = google_secret_manager_secret.integration.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.workload["api"].email}"
}
