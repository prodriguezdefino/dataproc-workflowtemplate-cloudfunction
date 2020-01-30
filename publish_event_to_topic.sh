#!/usr/bin/env bash

set -e
# sends a dummy workflow execution request

topic_name=$1
hive_script_location=$2

req_msg=$(cat <<EOM
{
  "job_name":"example-name",
  "jobs":[
    {
      "step_id":"step1",
      "hive_job": {
        "query_file_uri": "$hive_script_location"
      }
    }
  ],
  "cluster_init_actions": [
    {
      "executable_file": "gs://pabs-tf-tests-cf-dataproc-workflow-scripts/init_actions/execute_script.sh",
      "execution_timeout": 700
    }
  ],
  "labels":{
    "execution-type":"test"
  },
  "metadata": {
    "driver-script-bucket" : "pabs-tf-tests-cf-dataproc-workflow-scripts",
    "driver-script-path" : "scripts",
    "driver-script-entry" : "run_hive.sh",
    "driver-script-command" : "bash "
  },
  "request_id":"3a73a812-3706-11ea-82c0-43a30c9fa836"
}
EOM
)

gcloud pubsub topics publish $1 --message "$req_msg"
