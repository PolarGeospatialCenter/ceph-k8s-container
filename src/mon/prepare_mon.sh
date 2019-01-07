#!/bin/bash
set -e

function prepare_mon {
  #Required Vars
  : "${FSID?}"
  : "${MON_NAME?}"

  touch /etc/ceph/ceph.conf

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
  ceph-mon --setuser ceph --setgroup ceph --cluster "${CLUSTER}" --mkfs -i "${MON_NAME}" --fsid $FSID --keyring $MON_KEYRING --mon-data "$MON_DATA_DIR" 

  # dir=$(ls -lah $MON_DATA_DIR)
  # log $dir

  exit 0
}
