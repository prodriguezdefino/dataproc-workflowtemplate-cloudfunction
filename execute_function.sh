gcloud functions call trigger-dataproc-jobs --data '{"jobName":"dragon", "jobs":[{"step_id":"step1", "pyspark_job": {"main_python_file_uri": "gs://SOME_AVAILABLE_BUCKET/sparktest.py"}}]}'
