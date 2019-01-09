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

  monmap_exists=$(ceph-monstore-tool /mon/data get monmap -- --out /tmp/monmap > /dev/null)$? || true

  # If monmap exists, update our ip
  if [[ $monmap_exists -eq 0 ]] ; then
    monmaptool --clobber --rm $MON_ID "/tmp/monmap"
    monmaptool --clobber --add $MON_ID $IP:6789 "/tmp/monmap"
    /usr/bin/ceph-mon "${DAEMON_OPTS[@]}" -i "${MON_ID}" --inject-monmap /tmp/monmap --mon-data "$MON_DATA_DIR" --public-addr $IP
  fi

  # start MON
  log "Starting Ceph-Mon"
  #while true; do sleep 2; done
  exec /usr/bin/ceph-mon "${DAEMON_OPTS[@]}" -i "${MON_ID}" --mon-data "$MON_DATA_DIR" --public-addr $IP
}
