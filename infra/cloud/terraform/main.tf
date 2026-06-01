locals {
  labels = {
    app         = "smartcity-zero-disk"
    environment = var.environment
    managed_by  = "terraform"
  }

  required_services = toset([
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
  ])

  sensor_readings_schema = [
    { name = "time", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "sensor_id", type = "STRING", mode = "REQUIRED" },
    { name = "metric", type = "STRING", mode = "REQUIRED" },
    { name = "value", type = "FLOAT", mode = "REQUIRED" },
    { name = "unit", type = "STRING", mode = "REQUIRED" },
    { name = "source", type = "STRING", mode = "REQUIRED" },
    { name = "latitude", type = "FLOAT", mode = "REQUIRED" },
    { name = "longitude", type = "FLOAT", mode = "REQUIRED" },
    { name = "quality_flag", type = "INTEGER", mode = "REQUIRED" },
    { name = "ingested_at", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "schema_version", type = "INTEGER", mode = "REQUIRED" },
  ]

  workload_identity_members = {
    ingestor  = "serviceAccount:${var.gcp_project_id}.svc.id.goog[${var.gke_namespace}/smartcity-ingestor]"
    writer    = "serviceAccount:${var.gcp_project_id}.svc.id.goog[${var.gke_namespace}/smartcity-writer]"
    analytics = "serviceAccount:${var.gcp_project_id}.svc.id.goog[${var.gke_namespace}/smartcity-analytics]"
  }
}

data "google_project" "current" {
  project_id = var.gcp_project_id
}

data "google_storage_project_service_account" "gcs_account" {
  project = var.gcp_project_id
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

resource "google_pubsub_topic" "video_events" {
  name                       = var.video_pubsub_topic_name
  labels                     = local.labels
  message_retention_duration = "86400s"

  depends_on = [google_project_service.required]
}

resource "google_pubsub_subscription" "video_agent" {
  name  = var.video_pubsub_subscription_name
  topic = google_pubsub_topic.video_events.name

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s"

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

resource "google_pubsub_topic_iam_member" "gcs_video_notification_publisher" {
  topic  = google_pubsub_topic.video_events.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

resource "google_storage_notification" "video_inbox" {
  bucket             = google_storage_bucket.cold_storage.name
  payload_format     = "JSON_API_V1"
  topic              = google_pubsub_topic.video_events.id
  event_types        = ["OBJECT_FINALIZE"]
  object_name_prefix = var.video_gcs_prefix

  depends_on = [google_pubsub_topic_iam_member.gcs_video_notification_publisher]
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
  schema              = jsonencode(local.sensor_readings_schema)

  external_data_configuration {
    autodetect    = false
    source_format = "PARQUET"
    source_uris = [
      "gs://${google_storage_bucket.cold_storage.name}/sensor_readings/*"
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

resource "google_pubsub_subscription_iam_member" "video_agent_subscriber" {
  subscription = google_pubsub_subscription.video_agent.name
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

resource "google_project_iam_member" "analytics_bigquery_job_user" {
  project = var.gcp_project_id
  role    = "roles/bigquery.jobUser"
  member  = google_service_account.analytics.member
}

resource "google_service_account_iam_member" "ingestor_workload_identity" {
  count = var.enable_workload_identity_bindings || var.enable_runtime_resources ? 1 : 0

  service_account_id = google_service_account.ingestor.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.workload_identity_members.ingestor

  depends_on = [google_container_cluster.runtime]
}

resource "google_service_account_iam_member" "writer_workload_identity" {
  count = var.enable_workload_identity_bindings || var.enable_runtime_resources ? 1 : 0

  service_account_id = google_service_account.writer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.workload_identity_members.writer

  depends_on = [google_container_cluster.runtime]
}

resource "google_service_account_iam_member" "analytics_workload_identity" {
  count = var.enable_workload_identity_bindings || var.enable_runtime_resources ? 1 : 0

  service_account_id = google_service_account.analytics.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.workload_identity_members.analytics

  depends_on = [google_container_cluster.runtime]
}

resource "google_container_cluster" "runtime" {
  count = var.enable_runtime_resources ? 1 : 0

  name                = var.gke_cluster_name
  location            = var.gcp_region
  enable_autopilot    = true
  deletion_protection = false

  workload_identity_config {
    workload_pool = "${var.gcp_project_id}.svc.id.goog"
  }

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {}
  resource_labels = local.labels

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "gke_node_artifact_registry_reader" {
  count = var.enable_runtime_resources ? 1 : 0

  project = var.gcp_project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"

  depends_on = [google_container_cluster.runtime]
}

resource "google_service_account" "github_actions" {
  count = var.enable_ci_cd_resources ? 1 : 0

  account_id   = var.github_actions_service_account_id
  display_name = "Smart City GitHub Actions"
  description  = "Publishes Smart City service images to Artifact Registry from GitHub Actions."
}

resource "google_project_iam_member" "github_actions_artifact_registry_writer" {
  count = var.enable_ci_cd_resources ? 1 : 0

  project = var.gcp_project_id
  role    = "roles/artifactregistry.writer"
  member  = google_service_account.github_actions[0].member
}

resource "google_iam_workload_identity_pool" "github_actions" {
  count = var.enable_ci_cd_resources ? 1 : 0

  workload_identity_pool_id = var.github_actions_pool_id
  display_name              = "GitHub Actions"
  description               = "OIDC trust pool for Smart City GitHub Actions image publishing."

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool_provider" "github_actions" {
  count = var.enable_ci_cd_resources ? 1 : 0

  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions[0].workload_identity_pool_id
  workload_identity_pool_provider_id = var.github_actions_provider_id
  display_name                       = "GitHub"
  description                        = "Allows main-branch GitHub Actions runs to publish Smart City images."

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = "attribute.repository == \"${var.github_repository}\" && attribute.ref == \"refs/heads/main\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_actions_workload_identity" {
  count = var.enable_ci_cd_resources ? 1 : 0

  service_account_id = google_service_account.github_actions[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions[0].name}/attribute.repository/${var.github_repository}"
}

resource "google_service_account_iam_member" "github_actions_token_creator" {
  count = var.enable_ci_cd_resources ? 1 : 0

  service_account_id = google_service_account.github_actions[0].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions[0].name}/attribute.repository/${var.github_repository}"
}
