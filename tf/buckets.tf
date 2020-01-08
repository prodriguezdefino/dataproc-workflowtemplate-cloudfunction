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

resource "google_storage_bucket" "functions_bucket" {
  name   = "${var.project}-cf-dataproc-workflow-functions"
  labels = local.labels
}

resource "google_storage_bucket" "scripts_bucket" {
  name   = "${var.project}-cf-dataproc-workflow-scripts"
  labels = local.labels
}

resource "google_storage_bucket" "configs_bucket" {
  name   = "${var.project}-cf-dataproc-workflow-configs"
  labels = local.labels
}

data "template_file" "cf_template" {
  template = "${file("${path.module}/functions/cf_launcher.py.tpl")}"
  vars = {
    project       = var.project
    script_bucket = google_storage_bucket.scripts_bucket.name
    config_bucket = google_storage_bucket.configs_bucket.name
    config_file   = "configurations.json"
  }
}

data "template_file" "cf_configs" {
  template = "${file("${path.module}/configs/configurations.json.tpl")}"
  vars = {
    labels = jsonencode(local.labels)
    zone   = var.zone
  }
}

data "archive_file" "function_zip" {
  type        = "zip"
  output_path = "${path.module}/files/cf_trigger_dataproc_jobs.zip"

  source {
    content  = data.template_file.cf_template.rendered
    filename = "main.py"
  }

  source {
    content  = file("${path.module}/functions/requirements.txt")
    filename = "requirements.txt"
  }
}

resource "google_storage_bucket_object" "function_object" {
  name   = "cf_trigger_dataproc_jobs-${data.archive_file.function_zip.output_base64sha256}.zip"
  bucket = google_storage_bucket.functions_bucket.name
  source = "${path.module}/files/cf_trigger_dataproc_jobs.zip"
}

resource "google_storage_bucket_object" "script_object" {
  name   = "sparktest.py"
  bucket = google_storage_bucket.scripts_bucket.name
  source = "${path.module}/scripts/sparktest.py"
}

resource "google_storage_bucket_object" "configs_object" {
  name    = "configurations.json"
  bucket  = google_storage_bucket.configs_bucket.name
  content = data.template_file.cf_configs.rendered
}
