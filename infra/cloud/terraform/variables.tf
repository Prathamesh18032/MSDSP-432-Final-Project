variable "gcp_project_id" {
  description = "Target GCP project ID. Replace before running terraform plan/apply."
  type        = string
  default     = "replace-me-project"
}

variable "gcp_region" {
  description = "Primary GCP region for regional resources."
  type        = string
  default     = "asia-south1"
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
  default     = "dev"
}

variable "pubsub_topic_name" {
  description = "Pub/Sub topic for normalized sensor readings."
  type        = string
  default     = "smartcity-readings"
}

variable "pubsub_dlq_topic_name" {
  description = "Pub/Sub dead-letter topic for readings that fail downstream processing."
  type        = string
  default     = "smartcity-dlq"
}

variable "pubsub_subscription_name" {
  description = "Subscription used by the hot writer service."
  type        = string
  default     = "smartcity-hot-writer"
}

variable "pubsub_max_delivery_attempts" {
  description = "Maximum Pub/Sub delivery attempts before routing to the dead-letter topic."
  type        = number
  default     = 5
}

variable "gcs_bucket" {
  description = "Cold-storage bucket for partitioned Parquet files. Must be globally unique before apply."
  type        = string
  default     = "replace-me-smartcity-iot"
}

variable "cold_storage_retention_days" {
  description = "Placeholder lifecycle retention age for cold Parquet objects."
  type        = number
  default     = 365
}

variable "bigquery_dataset" {
  description = "BigQuery dataset for historical analytics over cold Parquet data."
  type        = string
  default     = "smartcity_iot"
}

variable "artifact_registry_repository" {
  description = "Artifact Registry Docker repository for future service images."
  type        = string
  default     = "smartcity"
}

variable "gke_namespace" {
  description = "Kubernetes namespace used by future GKE workloads."
  type        = string
  default     = "smartcity"
}

variable "enable_workload_identity_bindings" {
  description = "Enable only after a GKE Workload Identity pool exists for the project."
  type        = bool
  default     = false
}

variable "enable_runtime_resources" {
  description = "Enable gated GKE Autopilot runtime resources."
  type        = bool
  default     = false
}

variable "gke_cluster_name" {
  description = "GKE Autopilot cluster name for cloud runtime workloads."
  type        = string
  default     = "smartcity-autopilot"
}
