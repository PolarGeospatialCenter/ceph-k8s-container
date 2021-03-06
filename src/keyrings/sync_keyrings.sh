#!/bin/bash
set -e

function sync_keyrings {
  #Required Vars
  : "${CLUSTER?}"

  ceph-conf --cluster ${CLUSTER}  --lookup mon_host
  keyring=$(ceph-conf "${CLI_OPTS[@]}" --lookup keyring)

  if [[ ! -e $keyring ]]; then
    log "Keyring $keyring does not exist"
  fi

  ping -c 1 $(ceph-conf "${CLI_OPTS[@]}" --lookup mon_host) || true

  ceph --cluster ${CLUSTER}  mon dump

  quorum=$(timeout 5 ceph "${CLI_OPTS[@]}" mon dump 2> /dev/null > /dev/null)$? || true
  log "Check for quorum returned $quorum"
  # If quorum add monitor
  if [[ $quorum -ne 0 ]] ; then
    log "Quorum does not exist, unable to sync keyrings"
    exit 1
  fi

  keyrings=$(ceph "${CLI_OPTS[@]}" auth list 2> /dev/null |grep client.)

  log "Found keyrings $keyrings"

  for entity in $keyrings; do
    ceph "${CLI_OPTS[@]}" auth get $entity 2>/dev/null > keyring
    secretName="ceph-$CLUSTER-$entity-keyring"

    log "Syncing keyring $entity to kuberentes with name $secretName"
    kubectl create secret generic $secretName --from-file=keyring=keyring --dry-run -o yaml | kubectl apply -f -

  done
  exit 0
}
