import logging
import base64
import json
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

def triggerDataprocJobs(message, context):
    event = None
    if not 'data' in message:
      print("no data in the pubsub message")
      return
    event = json.loads(base64.b64decode(message['data']).decode('utf-8'))
    print('received: ' + event)
    client = dataproc_v1.WorkflowTemplateServiceClient()

    project = '${project}'
    region = 'global'
    parent = client.region_path(project, region)

    zone = event.get('zone', 'us-central1-c')
    cluster_name = 'cluster-' + event.get('jobName', 'dataproc-workflow-test')
    labels = ${labels_instance}
    bucket = "${script_bucket}"
    cluster_init_actions = event.get('clusterInitActions', [])

    if not isinstance(cluster_init_actions, list):
        print("cluster initialization actions should be a list")
        return

    if not "jobs" in event.keys():
        print("jobs property not present in the event, no work to be done...")
        return

    template = {
        "name": "projects/{}/regions/{}/workflowTemplates/dummy-template-test".format(project, region),
        "version": 1,
        "placement": {
            "managed_cluster": {
                'cluster_name': cluster_name,
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
                    'initialization_actions' : cluster_init_actions
                },
                'labels': labels
            },
        },
        "jobs": event["jobs"]
    }

    response = client.instantiate_inline_workflow_template(parent, template)
    response.add_done_callback(callback)

    # Handle metadata.
    metadata = response.metadata
    print(metadata)
