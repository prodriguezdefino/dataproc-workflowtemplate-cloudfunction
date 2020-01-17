resource "google_dataproc_cluster" "history-server" {
  depends_on = [
    google_storage_bucket.dataproc_logging_bucket,
  ]

  project = var.project
  name    = var.history_server
  region  = var.region
  labels  = local.labels

  cluster_config {
    staging_bucket = google_storage_bucket.dataproc_staging_bucket.name
    master_config {
      num_instances = 1
      machine_type  = "n1-standard-4"

      disk_config {
        boot_disk_type    = "pd-standard"
        boot_disk_size_gb = 50
      }
    }

    software_config {
      image_version = "1.4.0-debian9"

      override_properties = {
        "dataproc:dataproc.allow.zero.workers"              = "true"
        "yarn:yarn.log-aggregation-enable"                  = "true"
        "yarn:yarn.nodemanager.remote-app-log-dir"          = "gs://${google_storage_bucket.dataproc_logging_bucket.name}/yarn/logs/"
        "yarn:yarn.log-aggregation.retain-seconds"          = "604800"
        "yarn:yarn.log.server.url"                          = "http://${var.history_server}-m:19888/jobhistory/logs"
        "mapred:mapreduce.jobhistory.always-scan-user-dir"  = "true"
        "mapred:mapreduce.jobhistory.address"               = "${var.history_server}-m:10020"
        "mapred:mapreduce.jobhistory.webapp.address"        = "${var.history_server}-m:19888"
        "mapred:mapreduce.jobhistory.done-dir"              = "gs://${google_storage_bucket.dataproc_logging_bucket.name}/done-dir"
        "mapred:mapreduce.jobhistory.intermediate-done-dir" = "gs://${google_storage_bucket.dataproc_logging_bucket.name}/intermediate-done-dir"
        "spark:spark.eventLog.dir"                          = "gs://${google_storage_bucket.dataproc_logging_bucket.name}/spark-events/"
        "spark:spark.history.fs.logDirectory"               = "gs://${google_storage_bucket.dataproc_logging_bucket.name}/spark-events/"
        "spark:spark.ui.enabled"                            = "true"
        "spark:spark.ui.filters"                            = "org.apache.spark.deploy.yarn.YarnProxyRedirectFilter"
        "spark:spark.yarn.historyServer.address"            = "${var.history_server}-m:18080"
      }
    }

    gce_cluster_config {
      tags       = [var.network_tag]
      subnetwork = module.vpc.subnets_self_links[0]
      zone       = var.zone
      metadata = {
        "enable-oslogin" = "TRUE"
      }
    }
  }
}
