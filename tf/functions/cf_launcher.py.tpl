import logging
from google.cloud import dataproc_v1

# Copyright 2018 Google LLC. All rights reserved. To the extent this Software is provided by Google (“Google Software”),
# it is provided for demonstrative purposes only, and is supplied "AS IS" without any warranties or support commitment.
# Google assumes no responsibility or liability for use of the Google Software, nor conveys any license or title under
# any patent, copyright, or mask work right to the Google Software. The Google Software is confidential to Google and
# any disclosure is subject to Google’s written prior agreement to such disclosure. Google reserves the right to make
# changes in the Google Software without notification. Notwithstanding the foregoing, if you have an applicable agreement
# with Google with respect to such software, your software usage rights, related restrictions and other terms are
# governed by the terms of that agreement, and the foregoing does not supersede that agreement.

def callback(operation_future):
    # Handle result.
    result = operation_future.result()
    print(result)

def triggerDataprocJobs(event, context):
    client = dataproc_v1.WorkflowTemplateServiceClient()

    project = '${project}'
    region = 'global'
    parent = client.region_path(project, region)

    zone = 'us-central1-c'
    clusterName = 'dataproc-workflow-test'
    labels = ${labels_instance}
    bucket = "${script_bucket}"
    pysparkFileName = "sparktest.py"
    mainPySparkFileGSLocation = "gs://{}/{}".format(bucket, pysparkFileName)
    loggingLevel = getattr(logging, 'INFO')

    template = {
        "name": "projects/{}/regions/{}/workflowTemplates/dummy-template-test".format(project, region),
        "version": 1,
        "placement": {
            "managed_cluster": {
                'cluster_name': clusterName,
                'config': {
                    'gce_cluster_config': {
                        'zone_uri': zone,
                        'service_account_scopes': [
                            'https://www.googleapis.com/auth/cloud.useraccounts.readonly',
                            'https://www.googleapis.com/auth/devstorage.full_control',
                            'https://www.googleapis.com/auth/logging.write'
                        ]
                    },
                    'master_config': {
                        'num_instances': 1,
                        'machine_type_uri': 'n1-standard-1'
                    },
                    'worker_config': {
                        'num_instances': 2,
                        'machine_type_uri': 'n1-standard-1'
                    },
                    'initialization_actions' : []
                },
                'labels': labels
            },
        },
        "jobs": [{
            "step_id": "step1",
            "pyspark_job": {
                "main_python_file_uri": mainPySparkFileGSLocation,
                "args": [],
                "python_file_uris": [],
                "jar_file_uris": [],
                "file_uris": [],
                "archive_uris": [],
                "properties": {},
                "logging_config": {
                    "driver_log_levels":{
                        "root": loggingLevel
                    }
                }
            },
            "prerequisite_step_ids": []
        },
        {
            "step_id": "step2",
            "pyspark_job": {
                "main_python_file_uri": mainPySparkFileGSLocation,
                "args": [],
                "python_file_uris": [],
                "jar_file_uris": [],
                "file_uris": [],
                "archive_uris": [],
                "properties": {},
                "logging_config": {
                    "driver_log_levels":{
                        "root": loggingLevel
                    }
                }
            },
            "prerequisite_step_ids": ["step1"]
        }]
    }

    response = client.instantiate_inline_workflow_template(parent, template)
    response.add_done_callback(callback)

    # Handle metadata.
    metadata = response.metadata
    print(metadata)
