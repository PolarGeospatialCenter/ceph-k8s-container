#!/bin/bash
set -e

function get_mon_config {
  # Get fsid from ceph.conf
  local fsid
  fsid=$(ceph-conf --lookup fsid -c /etc/ceph/"${CLUSTER}".conf)

  local timeout=10
  local monmap_add=""
  while [[ -z "${monmap_add// }" && "${timeout}" -gt 0 ]]; do
    # Get the ceph mon pods (name and IP) from the Kubernetes API. Formatted as a set of monmap params
    if [[ ${K8S_HOST_NETWORK} -eq 0 ]]; then
      monmap_add=$(kubectl get pods --selector="${K8S_MON_SELECTOR}" -o template --template="{{range .items}}{{if .status.podIP}}--add {{.metadata.name}} {{.status.podIP}}:6789 {{end}} {{end}}")
    else
      monmap_add=$(kubectl get pods --selector="${K8S_MON_SELECTOR}" -o template --template="{{range .items}}{{if .status.podIP}}--add {{.metadata.nodeName}} {{.status.podIP}}:6789 {{end}} {{end}}")
    fi
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

function start_mon {

  if [ ! -e "$MON_DATA_DIR/keyring" ]; then
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
  else
    log "Existing mon, trying to rejoin cluster..."

    if [[ ! -f "$MON_MAP" ]]; then
      get_mon_config
    fi
    # Be sure that the mon name of the current monitor in the monmap is equal to ${MON_NAME}.
    # Names can be different in case of full qualifed hostnames
    MON_ID=$(monmaptool --print ${MON_MAP} | sed -n "s/^.*${MON_IP}:6789.*mon\.//p")
    if [[ -n "$MON_ID" && "$MON_ID" != "$MON_NAME" ]]; then
      monmaptool --rm $MON_ID $MON_MAP >/dev/null
      monmaptool --add $MON_NAME $MON_IP $MON_MAP >/dev/null
    fi
    ceph-mon --setuser ceph --setgroup ceph --cluster "${CLUSTER}" -i "${MON_NAME}" --inject-monmap "$MON_MAP" --keyring "$MON_KEYRING" --mon-data "$MON_DATA_DIR"

    timeout 7 ceph "${CLI_OPTS[@]}" mon add "${MON_NAME}" "${MON_IP}:6789" || true
  fi

  # start MON
  log "Starting Ceph-Mon"
  #while true; do sleep 2; done
  exec /usr/bin/ceph-mon "${DAEMON_OPTS[@]}" -i "${MON_NAME}" --mon-data "$MON_DATA_DIR" --public-addr "${MON_IP}:6789"
}
