#!/bin/bash
set -e

function sync_keyrings {
  #Required Vars
  : "${CLUSTER?}"

  quorum=$(timeout 5 ceph ${CLI_OPTS[@]} mon dump 2> /dev/null > /dev/null)$? || true
  log "Check for quorum returned $quorum"
  # If quorum add monitor
  if [[ $quorum -ne 0 ]] ; then
    log "Quorum does not exist, unable to sync keyrings"
    exit 1
  fi

  keyrings=$(ceph auth list 2> /dev/null |grep client.)

  for entity in keyrings; do
    ceph auth get $entity 2>/dev/null > keyring
    secretName="ceph-$CLUSTER-$entity-keyring"

    kubectl create secret generic $secretName --from-file=keyring=keyring --dry-run -o yaml | kubectl apply -f -

  done
  exit 0
}
