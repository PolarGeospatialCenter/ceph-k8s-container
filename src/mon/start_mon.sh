#!/bin/bash
set -e

function start_mon {
  # Required Vars
  : "${MON_ID?}"

  IP=`hostname -i`
  echo $IP
  # Run checks for keyring and ceph-conf.
  #touch /etc/ceph/ceph.conf

  # Error if mon data directory does not exist.
  if [ ! -e "$MON_DATA_DIR/keyring" ]; then
    log "Monitor data directory does not exist, exiting..."
    exit 1
  fi

  FSID=$(ceph-conf --lookup fsid)
  monmaptool --create --fsid "${FSID}" "/tmp/monmap"

  /usr/bin/ceph-mon "${DAEMON_OPTS[@]}" -i "${MON_ID}" --inject-monmap /tmp/monmap --mon-data "$MON_DATA_DIR" --public-addr $IP

    # start MON
  log "Starting Ceph-Mon"
  #while true; do sleep 2; done
  exec /usr/bin/ceph-mon "${DAEMON_OPTS[@]}" -i "${MON_ID}" --mon-data "$MON_DATA_DIR" --public-addr $IP
}
