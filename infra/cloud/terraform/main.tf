locals {
  labels = {
    app         = "smartcity-zero-disk"
    environment = var.environment
    managed_by  = "terraform"
  }

  required_services = toset([
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
  ])

  workload_identity_members = {
    ingestor  = "serviceAccount:${var.gcp_project_id}.svc.id.goog[${var.gke_namespace}/smartcity-ingestor]"
    writer    = "serviceAccount:${var.gcp_project_id}.svc.id.goog[${var.gke_namespace}/smartcity-writer]"
    analytics = "serviceAccount:${var.gcp_project_id}.svc.id.goog[${var.gke_namespace}/smartcity-analytics]"
  }
}

data "google_project" "current" {
  project_id = var.gcp_project_id
}

resource "google_project_service" "required" {
  for_each = local.required_services

  service            = each.key
  disable_on_destroy = false
}

resource "google_pubsub_topic" "sensor_readings" {
  name                       = var.pubsub_topic_name
  labels                     = local.labels
  message_retention_duration = "86400s"

  depends_on = [google_project_service.required]
}

resource "google_pubsub_topic" "dead_letter" {
  name   = var.pubsub_dlq_topic_name
  labels = local.labels

  depends_on = [google_project_service.required]
}

resource "google_pubsub_subscription" "hot_writer" {
  name  = var.pubsub_subscription_name
  topic = google_pubsub_topic.sensor_readings.name

  ack_deadline_seconds       = 30
  message_retention_duration = "604800s"

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = var.pubsub_max_delivery_attempts
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  labels = local.labels
}

resource "google_storage_bucket" "cold_storage" {
  name                        = var.gcs_bucket
  location                    = var.gcp_region
  uniform_bucket_level_access = true
  force_destroy               = false
  labels                      = local.labels

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age = var.cold_storage_retention_days
    }
  }

  depends_on = [google_project_service.required]
}

resource "google_bigquery_dataset" "analytics" {
  dataset_id                 = var.bigquery_dataset
  location                   = var.gcp_region
  delete_contents_on_destroy = false
  labels                     = local.labels

  depends_on = [google_project_service.required]
}

resource "google_bigquery_table" "sensor_readings_external" {
  dataset_id          = google_bigquery_dataset.analytics.dataset_id
  table_id            = "sensor_readings_external"
  deletion_protection = false
  labels              = local.labels

  external_data_configuration {
    autodetect    = true
    source_format = "PARQUET"
    source_uris = [
      "gs://${google_storage_bucket.cold_storage.name}/sensor_readings/source=*/metric=*/year=*/month=*/day=*/*.parquet"
    ]
  }
}

resource "google_artifact_registry_repository" "services" {
  location      = var.gcp_region
  repository_id = var.artifact_registry_repository
  description   = "Smart City service container images"
  format        = "DOCKER"
  labels        = local.labels

  depends_on = [google_project_service.required]
}

resource "google_service_account" "ingestor" {
  account_id   = "smartcity-ingestor"
  display_name = "Smart City Ingestor"
  description  = "Publishes normalized sensor readings to Pub/Sub."
}

resource "google_service_account" "writer" {
  account_id   = "smartcity-writer"
  display_name = "Smart City Writer"
  description  = "Consumes Pub/Sub readings and writes hot/cold storage outputs."
}

resource "google_service_account" "analytics" {
  account_id   = "smartcity-analytics"
  display_name = "Smart City Analytics"
  description  = "Reads BigQuery and cold storage for dashboards and reports."
}

resource "google_pubsub_topic_iam_member" "ingestor_publisher" {
  topic  = google_pubsub_topic.sensor_readings.name
  role   = "roles/pubsub.publisher"
  member = google_service_account.ingestor.member
}

resource "google_pubsub_subscription_iam_member" "writer_subscriber" {
  subscription = google_pubsub_subscription.hot_writer.name
  role         = "roles/pubsub.subscriber"
  member       = google_service_account.writer.member
}

resource "google_pubsub_topic_iam_member" "pubsub_dead_letter_publisher" {
  topic  = google_pubsub_topic.dead_letter.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription_iam_member" "pubsub_dead_letter_subscriber" {
  subscription = google_pubsub_subscription.hot_writer.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_storage_bucket_iam_member" "writer_cold_storage" {
  bucket = google_storage_bucket.cold_storage.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.writer.member
}

resource "google_storage_bucket_iam_member" "analytics_cold_storage" {
  bucket = google_storage_bucket.cold_storage.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.analytics.member
}

resource "google_bigquery_dataset_iam_member" "writer_dataset_editor" {
  dataset_id = google_bigquery_dataset.analytics.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_service_account.writer.member
}

resource "google_bigquery_dataset_iam_member" "analytics_dataset_viewer" {
  dataset_id = google_bigquery_dataset.analytics.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = google_service_account.analytics.member
}

resource "google_service_account_iam_member" "ingestor_workload_identity" {
  service_account_id = google_service_account.ingestor.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.workload_identity_members.ingestor
}

resource "google_service_account_iam_member" "writer_workload_identity" {
  service_account_id = google_service_account.writer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.workload_identity_members.writer
}

resource "google_service_account_iam_member" "analytics_workload_identity" {
  service_account_id = google_service_account.analytics.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.workload_identity_members.analytics
}
