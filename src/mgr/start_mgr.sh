#!/bin/bash
set -e

function start_mgr {
  : "${DAEMON_ID?}"

  check_config

  # Check to see if our MGR has been initialized
  if [ ! -e "$MGR_KEYRING" ]; then
    mkdir -p $(dirname $MGR_KEYRING)
    #check_admin_key
    # Create ceph-mgr key
    ceph "${CLI_OPTS[@]}" auth --keyring $MGR_BOOTSTRAP_KEYRING --name client.bootstrap-mgr \
      get-or-create mgr."$DAEMON_ID" mon 'allow profile mgr' osd 'allow *' mds 'allow *' -o "$MGR_KEYRING"
    chown "${CHOWN_OPT[@]}" ceph. "$MGR_KEYRING"
    chmod 600 "$MGR_KEYRING"
  fi

  log "Starting Ceph Mgr"
  # start ceph-mgr
  #while true; do sleep 2; done
  exec /usr/bin/ceph-mgr "${DAEMON_OPTS[@]}" --keyring $MGR_KEYRING -i "$DAEMON_ID"
}
