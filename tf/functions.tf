/**
 * Copyright 2018 Google LLC. All rights reserved. To the extent this Software is provided by Google (“Google Software”),
 * it is provided for demonstrative purposes only, and is supplied "AS IS" without any warranties or support commitment.
 * Google assumes no responsibility or liability for use of the Google Software, nor conveys any license or title under
 * any patent, copyright, or mask work right to the Google Software. The Google Software is confidential to Google and
 * any disclosure is subject to Google’s written prior agreement to such disclosure. Google reserves the right to make
 * changes in the Google Software without notification. Notwithstanding the foregoing, if you have an applicable agreement
 * with Google with respect to such software, your software usage rights, related restrictions and other terms are
 * governed by the terms of that agreement, and the foregoing does not supersede that agreement.
 */

resource "google_cloudfunctions_function" "function_trigger_dataproc_workflow" {
  name        = "dataproc-workflow-trigger"
  description = "Triggers the execution of a Dataproc workflow, creating a ephemeral cluster and executing a chain of tasks."
  runtime     = "python37"
  entry_point = "trigger_dataproc_jobs"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.functions_bucket.name
  source_archive_object = google_storage_bucket_object.function_object.name
  labels                = local.labels
  service_account_email = google_service_account.sa_cf_executor.email

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.dataproc_workflow_cf_trigger.name
    failure_policy {
      retry = "false"
    }
  }

  depends_on = [
    google_project_service.dataproc_service,
    google_project_service.cfunctions_service,
    google_storage_bucket_object.function_object,
    google_storage_bucket_object.configs_object
  ]
}

resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = var.project
  region         = var.region
  cloud_function = google_cloudfunctions_function.function_trigger_dataproc_workflow.name

  role   = "roles/cloudfunctions.invoker"
  member = "user:prodriguezdefino@gmail.com"
}
