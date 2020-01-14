#!/usr/bin/env bash

# sends a dummy workflow execution request

topic_name=$1
pyspark_script_location=$2
gcloud pubsub topics publish $1 --message "{\"job_name\":\"example-name\", \"jobs\":[{\"step_id\":\"step1\", \"pyspark_job\": {\"main_python_file_uri\": \"$pyspark_script_location\"}}], \"labels\":{\"execution-type\":\"test\"}, \"request_id\":\"3a63a812-3706-11ea-82c0-43a30c9fa836\"}"
