#!/bin/bash
set -e

function start_mds {
  : "${DAEMON_ID?}"

  check_config

  # Check to see if our MDS has been initialized
  if [ ! -e "$MDS_KEYRING" ]; then
    mkdir -p $(dirname $MDS_KEYRING)
    #check_admin_key
    # Create ceph-mds key
    ceph "${CLI_OPTS[@]}" auth --keyring $MDS_BOOTSTRAP_KEYRING --name client.bootstrap-mds \
      get-or-create mds."$DAEMON_ID" osd "allow rwx" mds "allow" mon "allow profile mds" -o "$MDS_KEYRING"
    chown "${CHOWN_OPT[@]}" ceph. "$MDS_KEYRING"
    chmod 600 "$MDS_KEYRING"
  fi

  log "Starting Ceph Mgr"
  # start ceph-mds
  #while true; do sleep 2; done
  exec /usr/bin/ceph-mds "${DAEMON_OPTS[@]}" --keyring $MDS_KEYRING -i "$DAEMON_ID" -d
}
