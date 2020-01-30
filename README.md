# Dataproc Inline Workflow Template creation from Cloud Functions

This repository holds the Terraform scripts and Cloud Function scripts needed to build a system that capture job execution requests and trigger those executions asynchronously as Dataproc jobs.

The GCP building blocks are based on this services:
 * __PubSub topics and subscriptions__ - Creates the request and response channels, in use by the clients to send executions and to follow up on the results
 * __Cloud Functions__                 - Implements the logic that capture the requests, coming as Pubsub messages, extract the job's information and, based on preset configurations, creates a Dataproc Inline Worflow instance that will create the needed cluster, execute the job or list of jobs and takes care of the deletion of the used resources after completion (being that failed or successful).
 * __Cloud Storage__                   - Stores the configuration of the cloud function, the scripts that are going to be executed as part of the workflow instances, holds all the execution logs and serves as the deployment facility for the Cloud Function code.
 * __Cloud IAM__                       - Creates and configure needed permissions for a Service Account in charge of running the Cloud Function

Terraform is in charge of creating all the needed GCP resources, the scripts can be found under the [tf](tf) directory and they are based on version [0.12](https://www.terraform.io/upgrade-guides/0-12.html) of Terraform. The default configuration file and constants values existing in the Python code are interpolations done with the names of the created GCP resources (topics and storage buckets), also the test PySpark script used for this solution is being deployed on a hosted GCS location.

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
      "executable_file": "gs://path/to/a/init_script",
      "execution_timeout": 700
    }
  ],
  "request_id": "", // used to check for potential duplication on the execution request
  "labels": { // set of labels that will be added to the cluster that will be instantiated
    "execution-type" : "test"
  }
}
```
This request will:
  * validate the parameters types
  * check if there is already another cluster running the proportioned `request_id` for the same `job_name`
  * instantiate a new cluster and run the specified init action with a custom timeout
  * execute the PySpark job contained in the location
  * when completed, destroy the cluster resources
  * propagate results to the created Pubsub topic for later inspection

For a complete reference, the `jobs` parameter's structure is completely based on the Python API for Dataproc jobs request (check docs [here](https://cloud.google.com/dataproc/docs/reference/rpc/google.cloud.dataproc.v1beta2#orderedjob)).

## Execute composed shell script

__Note:__ this is not intended to be run in a production setup, but it can help to troubleshoot execution and understand better current shell scripts that are run in an always-on cluster through `ssh`.

Is common to have shell scripts that run multiple hadoop, hive, spark workloads and migrating them to a workflow step type of execution may take time, so it could be useful to run a shell script that executes the compound workload right after the cluster has been initialized.

With this idea, we could then create a request that executes a dummy Dataproc workload as a step, for example a Hive query that returns the current timestamp, and include a `cluster_init_action` that uses the [`execute_script.sh`](tf/scripts/init_actions/execute_script.sh) shell script to include the desired Dataproc job execution as part of the initialization lifecycle.

This could be an example request:
```
{
  "job_name":"example-name",
  "jobs":[
    {
      "step_id":"step1",
      "hive_job": {
        "query_file_uri": "gs://some-gcs-location/with/dummy/hive/script.sql"
      }
    }
  ],
  "cluster_init_actions": [
    {
      "executable_file": "gs://some-gcs-location/init_actions/execute_script.sh",
      "execution_timeout": 700
    }
  ],
  "metadata": { // this metadata is set in the GCE instances of the cluster and used by the execute_script.sh init action
    "driver-script-bucket" : "some-gcs-location", // bucket name where the script files are stored
    "driver-script-path" : "scripts",             // path inside the bucket, the script will download the content recursively
    "driver-script-entry" : "run_hive.sh",        // the shell script to execute
    "driver-script-command" : "bash "             // the command to execute
  },
  "labels":{
    "execution-type":"test"
  },
  "request_id":"3a73a812-3706-11ea-82c0-43a30c9fa836"
}
```

The previous request could be changed to execute a Dataproc job, for example, by changing the `driver-script-command` entry to something like `hive -f ` and the `driver-script-entry` to an existing Hive script.

## Running the script from local environment

The Cloud Function script can be run locally or in a GCE instance if necessary, this are the steps to do so:
* install python3 and pip3
* properly configure the `gcloud` command to execute the python script using a defined GCP project.
* copy the contents of the [functions](/tf/functions) folder to a new location `mkdir -p tests && cp tf/functions tests`, then move to that folder `cd tests`
* install requirements with `pip3 install -r requirements.txt`
* create a file `request.json` with the request to be processed (review previous sections)
* modify script's constants in the file with meaningful values
* run the script with `python 3 main.py request.json`, the script will print out the request and the operation identifiers

__Note:__ the standalone script does not execute the future operation result callback, check on the workflow section of GCP console to review results.
