# Dataproc Inline Workflow Template creation from Cloud Functions

This repository holds the Terraform scripts and Cloud Function scripts needed to build a system that capture job execution requests and trigger those executions asynchronously as Dataproc jobs.

The GCP building blocks are based on this services:
 * _PubSub topics and subscriptions_ - Creates the request and response channels, in use by the clients to send executions and to follow up on the results
 * _Cloud Functions_                 - Implements the logic that capture the requests, coming as Pubsub messages, extract the job's information and, based on preset configurations, creates a Dataproc Inline Worflow instance that will create the needed cluster, execute the job or list of jobs and takes care of the deletion of the used resources after completion (being that failed or successful).
 * _Cloud Storage_                   - Stores the configuration of the cloud function, the scripts that are going to be executed as part of the workflow instances, holds all the execution logs and serves as the deployment facility for the Cloud Function code.
 * _Cloud IAM_                       - Creates and configure needed permissions for a Service Account in charge of running the Cloud Function

Terraform is in charge of creating all the needed GCP resources, the scripts can be found under the [tf](tf) directory. The default configuration file and constants values existing in the Python code are interpolations done with the names of the created GCP resources (topics and storage buckets), also the test PySpark script used for this solution is being deployed on a hosted GCS location.

## Configuration File

The configuration file for the solution stores the cluster configurations that will be used to execute job requests from the clients. It's a JSON file structured conveniently to match the cluster configuration used by the Dataproc workflow template specification for the Python API (information of the API can be found [here](https://googleapis.dev/python/dataproc/latest/_modules/google/cloud/dataproc_v1/gapic/workflow_template_service_client.html#WorkflowTemplateServiceClient.instantiate_inline_workflow_template)). By default it holds a default configuration entry, as noted by the next example:  
```
{
  "default_cluster_config": {
    "cluster_name": "default_cluster_name",
    "config": {
        "config_bucket": "dummy-cf-dataproc-workflow-staging",
        "gce_cluster_config": {
            "zone_uri": "us-central1-c",
            "service_account_scopes": [
                "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
                "https://www.googleapis.com/auth/devstorage.full_control",
                "https://www.googleapis.com/auth/logging.write"
            ]
        },
        "master_config": {
            "num_instances": 1,
            "machine_type_uri": "n1-standard-1"
        },
        "worker_config": {
            "num_instances": 2,
            "machine_type_uri": "n1-standard-1"
        },
        "software_config":{
          "properties": {
            "yarn:yarn.log-aggregation-enable": "true",
            "yarn:yarn.nodemanager.remote-app-log-dir": "gs://dummy-cf-dataproc-workflow-logs/yarn/logs/",
            "yarn:yarn.log-aggregation.retain-seconds": "604800",
            "mapred:mapreduce.jobhistory.done-dir": "gs://dummy-cf-dataproc-workflow-logs/done-dir/",
            "mapred:mapreduce.jobhistory.intermediate-done-dir": "gs://dummy-cf-dataproc-workflow-logs/intermediate-done-dir/",
            "spark:spark.eventLog.dir": "gs://dummy-cf-dataproc-workflow-logs/spark-events",
            "spark:spark.history.fs.logDirectory": "gs://dummy-cf-dataproc-workflow-logs/spark-events"
          }
        },
        "initialization_actions" : []
    },
    "labels": {"app":"test-app","team":"analytics"}
  }
}
```
When needed more configurations can be added, the property key used to add more configuration entries should be the `job_name` used on the requests, the Cloud Function will take care on extracting that value from the request and checking if the configuration entry exists, if it does not then will default the values accordingly.

## Request Example

A request example can be found as part of the `publish_event_to_topic.sh` script, this can be tailored as needed to include multiple customizations. The expected structure of the Pubsub message which triggers execution requests can be found next:
```
{
  "job_name": "example-name", // name of the job, will be used to scan for specific cluster configurations
  "jobs": [                   // a list of dataproc based jobs to be executed, this can be ordered using pre-requisites.
    {
      "step_id": "step1",
      "pyspark_job": {
        "main_python_file_uri": "gs://some-gcs-location/with/pyspark/script"
      }
    }
  ],
  "cluster_init_actions": [
    {
      "executable_file": "gs://path/to/a/init_script"
    }
  ]
}
```
This request will instantiate a new cluster, execute the PySpark job contained in the location, wait for the completion, destroy the cluster resources and propagate results to the created Pubsub topic for later inspection. For a complete reference, the `jobs` parameter's structure is completely based on the Python API for Dataproc jobs request (check docs [here](https://cloud.google.com/dataproc/docs/reference/rpc/google.cloud.dataproc.v1beta2#orderedjob)).
