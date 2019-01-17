#!/bin/bash

: ${NODE_NAME?}

NODE_JSON=$(kubectl get node ${NODE_NAME} -o json)
BUILDING=$(echo ${NODE_JSON} | jq -r .metadata.labels.building)
ROOM=$(echo ${NODE_JSON} | jq -r .metadata.labels.room)
RACK=$(echo ${NODE_JSON} | jq -r .metadata.labels.rack)
NODE=$(echo -n ${NODE_NAME} | cut -f 1 -d '.')

echo "root=default datacenter=${BUILDING}-${ROOM} rack=${RACK} node=${NODE}" > /ceph/crush-location
