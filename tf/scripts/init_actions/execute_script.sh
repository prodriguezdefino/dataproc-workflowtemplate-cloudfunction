#!/bin/bash
set -euxo pipefail
role="$(/usr/share/google/get_metadata_value attributes/dataproc-role)"

if [[ "${role}" == "Master" ]]; then
  # extract metadata from client request
  bucket="$(/usr/share/google/get_metadata_value attributes/driver-script-bucket)"
  path="$(/usr/share/google/get_metadata_value attributes/driver-script-path)"
  entry="$(/usr/share/google/get_metadata_value attributes/driver-script-entry)"
  command="$(/usr/share/google/get_metadata_value attributes/driver-script-command)"

  # prepare a folder to store exec scripts
  mkdir -p /tmp/execution

  # download the scripts from GCS
  gsutil cp -r "gs://$bucket/$path" /tmp/execution

  # create an execution user with enough permissions
  useradd -m -s $(which bash) -G hadoop,hdfs,yarn,mapred,hive,kafka,knox,solr,spark,zeppelin,gcsadmin jobexec

  echo "script execution"

  # request execution for this user
  su - jobexec -c "cd /tmp/execution/$path && $command $entry"

fi
