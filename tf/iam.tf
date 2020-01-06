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

resource "google_service_account" "sa_cf_executor" {
  account_id   = "sa-cf-executor"
  display_name = "Dataproc Worflow CF Executor"
}

resource "google_project_iam_custom_role" "role_cf_executor" {
  role_id     = "dataproc_workflow_cf_executor"
  title       = "Dataproc Workflow Executor for Service Accounts"
  description = "Enables the execution of Dataproc Worflows for Service Accounts"
  permissions = [
    "dataproc.workflowTemplates.instantiateInline",
    "dataproc.operations.get",
    "dataproc.operations.cancel",
    "logging.logEntries.create",
    "monitoring.metricDescriptors.create",
    "monitoring.metricDescriptors.get",
    "monitoring.metricDescriptors.list",
    "monitoring.monitoredResourceDescriptors.get",
    "monitoring.monitoredResourceDescriptors.list",
    "monitoring.timeSeries.create",
    "storage.buckets.get",
    "storage.objects.create",
    "storage.objects.get",
    "storage.objects.list",
    "storage.objects.update",
    "storage.objects.delete"
  ]
}

resource "google_project_iam_member" "project" {
  project = var.project
  role    = "projects/${var.project}/roles/${google_project_iam_custom_role.role_cf_executor.role_id}"
  member  = "serviceAccount:${google_service_account.sa_cf_executor.email}"
}
