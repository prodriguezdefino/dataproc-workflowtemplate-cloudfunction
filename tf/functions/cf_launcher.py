import logging
import base64
import json
from functools import partial
from google.cloud import dataproc_v1
from google.cloud import storage
from google.cloud import pubsub_v1

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

def result_propagation_callback(future):
    print("Workflow result Pubsub message notification id {} ".format(future.result()))

def propagate_result(result):
    publisher = pubsub_v1.PublisherClient()
    topic_path = publisher.topic_path('${project}', '${propagate_results_topic}')
    future = publisher.publish(topic_path, data=json.dumps(result).encode("utf-8"))
    future.add_done_callback(result_propagation_callback)

def execution_callback(operation_future, template_name, cluster_name,
            metadata):
    # Handle workflow execution result.
    result = str(operation_future.result()) if operation_future.result() is not None or operation_future.result() is not Empty else 'ok'
    metadata['cluster_name'] = operation_future.metadata.cluster_name
    metadata['cluster_uuid'] = operation_future.metadata.cluster_uuid
    metadata['template'] = operation_future.metadata.template
    metadata['version'] = operation_future.metadata.version
    metadata['start_time'] = str(operation_future.metadata.start_time)
    metadata['end_time'] = str(operation_future.metadata.end_time)
    metadata['exec_graph'] = str(operation_future.metadata.graph)
    metadata['state'] = operation_future.metadata.state

    propagate_result({'metadata': metadata, 'result': result})

def trigger_dataproc_jobs(message, context):
    event = None
    if not 'data' in message:
        print("no data in the Pubsub message, nothing to do...")
        return
    event = json.loads(base64.b64decode(message['data']).decode('utf-8'))
    dataproc_client = dataproc_v1.WorkflowTemplateServiceClient()
    storage_client = storage.Client()

    config = retrieve_configuration(storage_client)

    project = '${project}'
    region = 'global'
    parent = dataproc_client.region_path(project, region)

    zone = event.get('zone', 'us-central1-c')
    job_name = event.get('job_name', 'dataproc-workflow-test')
    template_name = "projects/{}/regions/{}/workflowTemplates/{}".format(project, region, job_name)
    cluster_name = 'cluster-' + job_name
    config['cluster_config']['cluster_name'] = cluster_name

    bucket = '${script_bucket}'
    cluster_init_actions = event.get('cluster_init_actions', [])

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

    metadata = {
        'operation_name': response.operation.name
    }

    print('workflow instance created, operation\'s name: {}'.format(metadata['operation_name']))

    response.add_done_callback(partial(execution_callback, template_name=template_name,
            cluster_name=cluster_name, metadata=metadata))
