output "pubsub_topic" {
  description = "Normalized sensor readings topic."
  value       = google_pubsub_topic.sensor_readings.name
}

output "pubsub_dead_letter_topic" {
  description = "Dead-letter topic for failed downstream processing."
  value       = google_pubsub_topic.dead_letter.name
}

output "video_pubsub_topic" {
  description = "Video object notification topic for the optional AI agent."
  value       = google_pubsub_topic.video_events.name
}

output "video_pubsub_subscription" {
  description = "Subscription consumed by the optional video AI agent."
  value       = google_pubsub_subscription.video_agent.name
}

output "cold_storage_bucket" {
  description = "Cold Parquet storage bucket."
  value       = google_storage_bucket.cold_storage.name
}

output "bigquery_dataset" {
  description = "BigQuery analytics dataset."
  value       = google_bigquery_dataset.analytics.dataset_id
}

output "artifact_registry_repository" {
  description = "Artifact Registry Docker repository."
  value       = google_artifact_registry_repository.services.name
}

output "workload_service_accounts" {
  description = "Google service account emails for GKE Workload Identity bindings."
  value = {
    ingestor  = google_service_account.ingestor.email
    writer    = google_service_account.writer.email
    analytics = google_service_account.analytics.email
  }
}

output "gke_cluster_name" {
  description = "GKE Autopilot cluster name when runtime resources are enabled."
  value       = var.enable_runtime_resources ? google_container_cluster.runtime[0].name : null
}

output "gke_cluster_location" {
  description = "GKE cluster location when runtime resources are enabled."
  value       = var.enable_runtime_resources ? google_container_cluster.runtime[0].location : null
}

output "github_actions_workload_identity_provider" {
  description = "Workload Identity Provider resource name for GitHub Actions image publishing."
  value       = var.enable_ci_cd_resources ? google_iam_workload_identity_pool_provider.github_actions[0].name : null
}

output "github_actions_service_account" {
  description = "GitHub Actions service account email for Artifact Registry publishing."
  value       = var.enable_ci_cd_resources ? google_service_account.github_actions[0].email : null
}
