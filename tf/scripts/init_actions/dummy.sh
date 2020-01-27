#!/bin/bash
set -euxo pipefail
role="$(/usr/share/google/get_metadata_value attributes/dataproc-role)"

if [[ "${role}" == "Master" ]]; then

  echo "Master of puppets!"
fi
