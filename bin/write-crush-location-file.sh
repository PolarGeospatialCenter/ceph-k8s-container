#!/bin/bash

: ${NODE_NAME?}
: ${STORAGE_BACKPLANE?}
: ${STORAGE_SLOT?}

NODE_JSON=$(kubectl get node ${NODE_NAME} -o json)
BUILDING=$(echo ${NODE_JSON} | jq -r .metadata.labels.building)
ROOM=$(echo ${NODE_JSON} | jq -r .metadata.labels.room)
RACK=$(echo ${NODE_JSON} | jq -r .metadata.labels.rack)
NODE=$(echo -n ${NODE_NAME} | cut -f 1 -d '.')
BACKPLANE=${STORAGE_BACKPLANE}
SLOT=${STORAGE_SLOT}

echo "root=default datacenter=${BUILDING}-${ROOM} rack=${RACK} node=${NODE} backplane=${NODE}-${BACKPLANE} slot=${NODE}-${BACKPLANE}-${SLOT}" > /ceph/crush-location
