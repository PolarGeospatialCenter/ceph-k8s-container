#!/bin/bash
set -e

function prepare_mon {
  #Required Vars
  : "${CLUSTER?}"
  : "${CLUSTER_NAMESPACE?}"
  : "${PV_LABEL_SELECTOR?}"

  FSID=$(kubectl get cephcluster $CLUSTER -n $CLUSTER_NAMESPACE -o template --template="{{.spec.fsid}}")
  MON_ID=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)

  touch /etc/ceph/$CLUSTER.conf

  # Error if mon data directory already exists.
  if [ -e "$MON_DATA_DIR/keyring" ]; then
    log "Monitor data directory already exists, exiting..."
    exit 1
  fi

  if [ ! -e "$MON_BOOTSTRAP_KEYRING" ]; then
    log "ERROR: $MON_BOOTSTRAP_KEYRING must exist."
    exit 1
  fi

  # Fix for Kubernetes read only secrets.
  mkdir -p "/tmp/ceph/mon/$CLUSTER-$MON_NAME"
  cp $MON_BOOTSTRAP_KEYRING $MON_KEYRING

  # Add Admin Keyring
  for keyring in $ADMIN_KEYRING; do
   if [ -f "$keyring" ]; then
     ceph-authtool "$MON_KEYRING" --import-keyring "$keyring"
   fi
  done

  # Prepare the monitor daemon's directory with the map and keyring
  #ceph-mon --setuser ceph --setgroup ceph --cluster "${CLUSTER}" --mkfs -i "${MON_NAME}" --inject-monmap "$MON_MAP" --keyring "$MON_KEYRING" --mon-data "$MON_DATA_DIR"
  ceph-mon --setuser ceph --setgroup ceph --cluster "${CLUSTER}" --mkfs -i "${MON_ID}" --fsid $FSID --keyring $MON_KEYRING --mon-data "$MON_DATA_DIR"

  # dir=$(ls -lah $MON_DATA_DIR)
  # log $dir

  cat << EOF > /tmp/mon.yaml
kind: CephMon
version: ceph.k8s.pgc.umn.edu/v1alpha1
metadata:
  name: $CLUSTER-mon.$MON_ID
  namespace: $CLUSTER_NAMESPACE
spec:
  clusterName: $CLUSTER
  ID: $MON_ID
  PvSelector: $PV_LABEL_SELECTOR
EOF

  kubectl apply -f /tmp/mon.yaml

  exit 0
}
