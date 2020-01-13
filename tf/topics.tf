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

resource "google_pubsub_topic" "dataproc_workflow_cf_trigger" {
  name   = "dataproc-workflow-cf-trigger"
  labels = local.labels
}

resource "google_pubsub_topic" "dataproc_workflow_cf_results" {
  name   = "dataproc-workflow-cf-results"
  labels = local.labels
}

resource "google_pubsub_subscription" "results_subscription" {
  name                 = "dataproc-workflow-cf-results-subscription"
  topic                = google_pubsub_topic.dataproc_workflow_cf_results.name
  ack_deadline_seconds = 600
  labels               = local.labels
}
