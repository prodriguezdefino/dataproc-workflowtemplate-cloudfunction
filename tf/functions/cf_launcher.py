import logging
import base64
import json
import time
import random
import sys
from functools import partial
from google.cloud import dataproc_v1
from google.cloud.dataproc_v1.gapic.transports import cluster_controller_grpc_transport
from google.cloud.dataproc_v1.gapic.transports import workflow_template_service_grpc_transport
from google.cloud import storage
from google.cloud import pubsub_v1
from google.protobuf import json_format
from google.protobuf.duration_pb2 import Duration

# Copyright 2018 Google LLC. All rights reserved. To the extent this Software is provided by Google (“Google Software”),
# it is provided for demonstrative purposes only, and is supplied "AS IS" without any warranties or support commitment.
# Google assumes no responsibility or liability for use of the Google Software, nor conveys any license or title under
# any patent, copyright, or mask work right to the Google Software. The Google Software is confidential to Google and
# any disclosure is subject to Google’s written prior agreement to such disclosure. Google reserves the right to make
# changes in the Google Software without notification. Notwithstanding the foregoing, if you have an applicable agreement
# with Google with respect to such software, your software usage rights, related restrictions and other terms are
# governed by the terms of that agreement, and the foregoing does not supersede that agreement.

# Constants, in case of local tests substitute the variables with proper names.
config_bucket = '${config_bucket}'
config_file = '${config_file}'
project_id = '${project}'
region_id = '${region}'
zone_id = '${zone}'
results_topic = '${propagate_results_topic}'

def retrieve_configuration(storage_client):
    """ Retrieves Cloud Function configuration
    Using the configured bucket and file, downloads the existing configuration
    and returns it as a JSON object.

    storage_client: an initialized GCS client
    """
    bucket = storage_client.get_bucket(config_bucket)
    blob = bucket.get_blob(config_file)

    return json.loads(blob.download_as_string())

def result_propagation_callback(future):
    """ Logs propagation result
    future: Pubsub publish operations result
    """
    print("Workflow result Pubsub message notification id {} ".format(future.result()))

def propagate_result(result):
    """ Workflow results propagation
    Propagates the execution's result to the configured Pubsub topic.

    result: workflow execution information
    """
    publisher = pubsub_v1.PublisherClient()
    topic_path = publisher.topic_path(project_id, results_topic)
    future = publisher.publish(topic_path, data=json.dumps(result).encode("utf-8"))
    future.add_done_callback(result_propagation_callback)

def execution_callback(operation_future, metadata):
    """ Handle workflow execution result
    Captures the execution request information, the result as well and propagates it.

    operation_future: the future reference for the execution, fulfilled when execution ends
    metadata: the workflow request metadata
    """

    result = 'error: ' + str(operation_future.exception()) if operation_future.exception() is not None else 'ok'
    metadata['cluster_name'] = operation_future.metadata.cluster_name
    metadata['cluster_uuid'] = operation_future.metadata.cluster_uuid
    metadata['template'] = operation_future.metadata.template
    metadata['version'] = operation_future.metadata.version
    metadata['start_time'] = operation_future.metadata.start_time.seconds
    metadata['end_time'] = operation_future.metadata.end_time.seconds
    metadata['exec_graph'] = json_format.MessageToDict(operation_future.metadata.graph)
    metadata['state'] = operation_future.metadata.state

    propagate_result({'metadata' : metadata, 'result' : result})

def trigger_dataproc_jobs(message, context):
    """ Entry point for the CloudFunction
    Captures a Pubsub message from the configured source topic and constructs a
    Dataproc Inline Workflow request to run the jobs specified in the message request.

    message: the Pubsub message
    context: the Cloud Function context information
    """

    if not 'data' in message:
        print("no data in the Pubsub message, nothing to do...")
        return
    event = json.loads(base64.b64decode(message['data']).decode('utf-8'))

    if not "jobs" in event.keys():
        print("jobs property not present in the event, no work to be done...")
        return

    # initialize needed GCP clients
    wf_client_transport = (workflow_template_service_grpc_transport
                    .WorkflowTemplateServiceGrpcTransport(
                        address="{}-dataproc.googleapis.com:443".format(region_id)))
    dataproc_workflow_client = dataproc_v1.WorkflowTemplateServiceClient(wf_client_transport)
    dp_client_transport = (cluster_controller_grpc_transport
        .ClusterControllerGrpcTransport(
            address='{}-dataproc.googleapis.com:443'.format(region_id)))
    dataproc_cluster_client = dataproc_v1.ClusterControllerClient(dp_client_transport)
    storage_client = storage.Client()

    # retrieves the cloud function configuration for storage
    config = retrieve_configuration(storage_client)

    # build parent region path for dataproc api requests
    parent = dataproc_workflow_client.region_path(project_id, region_id)

    # extract events parameters
    zone = event.get('zone', zone_id)
    job_name = event.get('job_name', 'dataproc-workflow-test')
    template_name = "projects/{}/regions/{}/workflowTemplates/{}".format(project_id, region_id, job_name)
    cluster_name = 'cluster-' + job_name
    cluster_init_actions = event.get('cluster_init_actions', [])
    request_id = event.get('request_id', template_name.replace('/', '_'))
    job_labels = event.get('labels', {})
    job_labels['job_name']= job_name
    job_labels['request_id']= request_id
    req_metadata = event.get('metadata', {})

    # lets check if there is another cluster with the same labels already running
    # randomizing the wait time we can improve the chances of catching duplicated requests
    time.sleep(random.randint(1, 5))
    for cluster in dataproc_cluster_client.list_clusters(project_id, region_id,
        'labels.job_name = {} AND labels.request_id = {}'.format(job_name, request_id)) :
        print(
            "workflow instance already running for same pair job_name and request_id ({},{}), exiting".format(
            job_name, request_id))
        return

    if not isinstance(cluster_init_actions, list):
        print("cluster initialization actions should be a list")
        return

    # check on the functions configuration for an entry for the job name in the execution request
    cluster_config = None
    if not job_name in config.keys():
        # if no particular configuration exists use default one
        cluster_config = config['default_cluster_config']
    else:
        cluster_config = config[job_name]

    cluster_config['labels'] = {**cluster_config['labels'], **job_labels}
    cluster_config['cluster_name'] = cluster_name
    cluster_config['config']['gce_cluster_config']['metadata'] = {**cluster_config['config']['gce_cluster_config']['metadata'], **req_metadata}
    cluster_config['config']['gce_cluster_config']['zone_uri'] = zone
    cluster_config['config']['initialization_actions'] = cluster_config['config']['initialization_actions'] + cluster_init_actions
    for action in cluster_config['config']['initialization_actions']:
        if 'execution_timeout' in action:
            timeout = Duration(seconds=action['execution_timeout'])
            action['execution_timeout'] = timeout

    # creates inline template request
    inline_template = {
      'name': template_name,
      'placement': {
          'managed_cluster': cluster_config
      },
      'jobs': event['jobs']
    }

    # sends the request to instantiate the workflow inlined template
    response = dataproc_workflow_client.instantiate_inline_workflow_template(parent,
        inline_template, request_id=request_id, metadata=[('job_name',job_name)])

    # captures operation name for the execution's metadata along with other request parameters
    metadata = {
        'operation_name': response.operation.name,
        'template_name': template_name,
        'cluster_name': cluster_name
    }

    print('workflow instance created, request id {}, operation\'s name: {}'.format(request_id, metadata['operation_name']))

    # Sets the future to be called when the workflow execution completes.
    # This partial function gets populated with local information, normally
    # not present at the callback execution time, to enrich logging and event
    # results propagation.
    response.add_done_callback(partial(execution_callback, metadata=metadata))


if __name__ == '__main__':
    request_file = sys.argv[1]
    with open(request_file, 'r') as content_file:
        content = content_file.read()
        message = {}
        message['data'] = base64.b64encode(content.encode('ascii'))
        trigger_dataproc_jobs(message,{})
