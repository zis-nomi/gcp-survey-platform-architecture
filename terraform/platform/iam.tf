resource "google_service_account" "nodes" {
  account_id   = "${var.name}-nodes"
  display_name = "GKE node system identity"
  depends_on   = [google_project_service.required]
}
resource "google_project_iam_member" "node_system" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.nodes.email}"
}
resource "google_service_account" "workload" {
  for_each     = local.workloads
  account_id   = "${var.name}-${each.key}"
  display_name = "Assessment ${each.key} workload"
  depends_on   = [google_project_service.required]
}
resource "google_service_account_iam_member" "workload_identity" {
  for_each           = local.workloads
  service_account_id = google_service_account.workload[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[assessment/${each.key}]"
  depends_on         = [google_container_cluster.main]
}
resource "google_project_iam_member" "sql_client" {
  for_each = local.workloads
  project  = var.project_id
  role     = "roles/cloudsql.client"
  member   = "serviceAccount:${google_service_account.workload[each.key].email}"
}
resource "google_project_iam_member" "sql_login" {
  for_each = local.workloads
  project  = var.project_id
  role     = "roles/cloudsql.instanceUser"
  member   = "serviceAccount:${google_service_account.workload[each.key].email}"
}
