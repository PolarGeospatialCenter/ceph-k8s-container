#!/bin/bash
set -e

function get_mon_config {
  sleep 5
  # Get fsid from ceph.conf
  local fsid
  fsid=$(ceph-conf --lookup fsid -c /etc/ceph/"${CLUSTER}".conf)

  local timeout=10
  local monmap_add=""
  while [[ -z "${monmap_add// }" && "${timeout}" -gt 0 ]]; do
    # Get the ceph mon pods (name and IP) from the Kubernetes API. Formatted as a set of monmap params
    monmap_add=$(kubectl get pods --selector="${K8S_MON_SELECTOR}" -o template --template="{{range .items}}{{if .status.podIP}}--add {{.metadata.name}} {{.status.podIP}}:6789 {{end}} {{end}}")
    (( timeout-- ))
    sleep 1
  done
  IFS=" " read -r -a monmap_add_array <<< "${monmap_add}"

  if [[ -z "${monmap_add// }" ]]; then
    log "No Ceph Monitor pods discovered. Abort mission!"
    exit 1
  fi

  # Create a monmap with the Pod Names and IP
  monmaptool --create "${monmap_add_array[@]}" --fsid "${fsid}" "$MON_MAP"

}

function mon_data_dir {
   get_mon_config

   if [ ! -e "$MON_BOOTSTRAP_KEYRING" ]; then
     log "ERROR- $MON_BOOTSTRAP_KEYRING must exist.  You can extract it from your current monitor by running 'ceph auth get mon. -o $MON_BOOTSTRAP_KEYRING' or use a KV Store"
     exit 1
   fi

   if [ ! -e "$MON_MAP" ]; then
     log "ERROR- $MON_MAP must exist.  You can extract it from your current monitor by running 'ceph mon getmap -o $MON_MAP' or use a KV Store"
     exit 1
   fi

   #Fix for Kubernetes read only secrets.
   mkdir -p "/tmp/ceph/mon/$CLUSTER-$MON_NAME"
   cp $MON_BOOTSTRAP_KEYRING $MON_KEYRING

   # Testing if it's not the first monitor, if one key doesn't exist we assume none of them exist
  for keyring in $OSD_BOOTSTRAP_KEYRING $MDS_BOOTSTRAP_KEYRING $RGW_BOOTSTRAP_KEYRING $RBD_MIRROR_BOOTSTRAP_KEYRING $ADMIN_KEYRING; do
    if [ -f "$keyring" ]; then
      ceph-authtool "$MON_KEYRING" --import-keyring "$keyring"
    fi
  done

  # Prepare the monitor daemon's directory with the map and keyring
  ceph-mon --setuser ceph --setgroup ceph --cluster "${CLUSTER}" --mkfs -i "${MON_NAME}" --inject-monmap "$MON_MAP" --keyring "$MON_KEYRING" --mon-data "$MON_DATA_DIR"

  dir=$(ls -lah $MON_DATA_DIR)
  log $dir

  # Never re-use that monmap again, otherwise we end up with partitioned Ceph monitor
  # The initial mon **only** contains the current monitor, so this is useful for initial bootstrap
  # Always rely on what has been populated after the other monitors joined the quorum
  rm -f "$MON_MAP"

}

function start_mon {
  # Required Vars
  : "${MON_IP?}"
  : "${MON_NAME?}"

  # Run checks for keyring and ceph-conf.

  # Build mon data directory if it does not exist.
  if [ ! -e "$MON_DATA_DIR/keyring" ]; then
    log "Monitor data directory does not exist, building..."
    mon_data_dir
  fi

  mkdir -p $MON_HISTORY_DIR

  pastIds=$(ls $MON_HISTORY_DIR)
  log "PastIDS: $pastIds"

  touch "$MON_HISTORY_DIR/$MON_NAME"

  # Check Quorum Status
  quorum=$(timeout 5 ceph -s > /dev/null)$? || true

  # If quorum add monitor
  if [[ $quorum -eq 0 ]] ; then
    log "Quorum exists, adding monitor to online cluster."

    currentMap=$(timeout 5 ceph mon dump)
    log "Current map: $currentMap"

    for id in $pastIds; do
      log "Checking current map for past id: $id"
      if echo $currentMap | grep -q $id; then
        log "Removing $id from cluster"
        ceph mon remove $id
        rm "$MON_HISTORY_DIR/$id"
      fi

    done

    timeout 7 ceph "${CLI_OPTS[@]}" mon add "${MON_NAME}" "${MON_IP}:6789"

  else
    # If no quorum wait for other monitors
    # Update some resource that we are waiting

    # Start Discovery Server
    # Get List of pods
    # try to connect to discovery server on each pod
    # If sucess increment counter
    # if counter is greater than n/2 then continue

    /bin/qtainer -w 2 -t 1m -n ceph -l "${K8S_MON_SELECTOR}"
    log "Qtainer exited sucessfully"
  fi

  get_mon_config
  ceph-mon --setuser ceph --setgroup ceph --cluster "${CLUSTER}" -i "${MON_NAME}" --inject-monmap "$MON_MAP" --keyring "$MON_KEYRING" --mon-data "$MON_DATA_DIR"

  # start MON
  log "Starting Ceph-Mon"
  #while true; do sleep 2; done
  exec /usr/bin/ceph-mon "${DAEMON_OPTS[@]}" -i "${MON_NAME}" --mon-data "$MON_DATA_DIR" --public-addr "${MON_IP}:6789"
}
