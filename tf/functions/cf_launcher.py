import logging
import base64
import json
from functools import partial
from google.cloud import dataproc_v1
from google.cloud import storage

# Copyright 2018 Google LLC. All rights reserved. To the extent this Software is provided by Google (“Google Software”),
# it is provided for demonstrative purposes only, and is supplied "AS IS" without any warranties or support commitment.
# Google assumes no responsibility or liability for use of the Google Software, nor conveys any license or title under
# any patent, copyright, or mask work right to the Google Software. The Google Software is confidential to Google and
# any disclosure is subject to Google’s written prior agreement to such disclosure. Google reserves the right to make
# changes in the Google Software without notification. Notwithstanding the foregoing, if you have an applicable agreement
# with Google with respect to such software, your software usage rights, related restrictions and other terms are
# governed by the terms of that agreement, and the foregoing does not supersede that agreement.

def retrieve_configuration(storage_client):
  config_bucket = '${config_bucket}'
  config_file = '${config_file}'

  bucket = storage_client.get_bucket(config_bucket)
  blob = bucket.get_blob(config_file)

  return json.loads(blob.download_as_string())

def execution_callback(operation_future, template_name, cluster_name, metadata):
  # Handle result.
  result = operation_future.result()
  print("executed {}, on cluster {}, with metadata {}, result: ".format(template_name, cluster_name, metadata))
  print(result if not None else 'ok')

def trigger_dataproc_jobs(message, context):
  event = None
  if not 'data' in message:
    print("no data in the pubsub message, nothing to do...")
    return
  event = json.loads(base64.b64decode(message['data']).decode('utf-8'))
  print('event received: ')
  print(event)
  dataproc_client = dataproc_v1.WorkflowTemplateServiceClient()
  storage_client = storage.Client()

  config = retrieve_configuration(storage_client)

  project = '${project}'
  region = 'global'
  parent = dataproc_client.region_path(project, region)

  zone = event.get('zone', 'us-central1-c')
  job_name = event.get('jobName', 'dataproc-workflow-test')
  template_name = "projects/{}/regions/{}/workflowTemplates/{}".format(project, region, job_name)
  cluster_name = 'cluster-' + job_name
  config['cluster_config']['cluster_name'] = cluster_name

  bucket = '${script_bucket}'
  cluster_init_actions = event.get('clusterInitActions', [])

  if not isinstance(cluster_init_actions, list):
      print("cluster initialization actions should be a list")
      return

  if not "jobs" in event.keys():
      print("jobs property not present in the event, no work to be done...")
      return

  template = {
      'name': template_name,
      'version': 1,
      'placement': {
          'managed_cluster': config['cluster_config'],
      },
      'jobs': event['jobs']
  }

  response = dataproc_client.instantiate_inline_workflow_template(parent, template)

  # Handle metadata.
  metadata = response.metadata
  print('workflow instance created, metadata: ')
  print(metadata)

  response.add_done_callback(partial(execution_callback, template_name=template_name, cluster_name=cluster_name, metadata=metadata))
