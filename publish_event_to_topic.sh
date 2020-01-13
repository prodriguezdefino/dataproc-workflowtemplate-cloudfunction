topic_name=$1
pyspark_script_location=$2
gcloud pubsub topics publish $1 --message "{\"job_name\":\"dragon\", \"jobs\":[{\"step_id\":\"step1\", \"pyspark_job\": {\"main_python_file_uri\": \"$pyspark_script_location\"}}]}"
