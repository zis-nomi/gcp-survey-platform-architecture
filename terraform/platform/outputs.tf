output "cluster_credentials_command" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.main.name} --region ${var.region} --project ${var.project_id} --internal-ip"
}
output "network_name" {
  value = google_compute_network.main.name
}
output "sql_connection_name" {
  value = google_sql_database_instance.main.connection_name
}
output "sql_database" {
  value = google_sql_database.app.name
}
output "database_iam_usernames" {
  value = { for key, user in google_sql_user.workload : key => user.name }
}
output "workload_service_accounts" {
  description = "Annotate assessment/api and assessment/worker KSAs with the corresponding GSA email."
  value       = { for key, account in google_service_account.workload : key => account.email }
}
output "files_bucket" {
  value = google_storage_bucket.files.name
}
output "image_repository" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}
output "integration_secret" {
  description = "Empty secret container. Add payload out of band if needed."
  value       = google_secret_manager_secret.integration.id
}
