#!/usr/bin/env bash

set -e
# sends a dummy workflow execution request

topic_name=$1
pyspark_script_location=$2

req_msg=$(cat <<EOM
{
  "job_name":"example-name",
  "jobs":[
    {
      "step_id":"step1",
      "pyspark_job": {
        "main_python_file_uri": "$pyspark_script_location"
      }
    }
  ],
  "cluster_init_actions": [
    {
      "executable_file": "gs://pabs-tf-tests-cf-dataproc-workflow-scripts/init_actions/dummy.sh",
      "execution_timeout": 700
    }
  ],
  "labels":{
    "execution-type":"test"
  },
  "request_id":"3a73a812-3706-11ea-82c0-43a30c9fa836"
}
EOM
)

gcloud pubsub topics publish $1 --message "$req_msg"
