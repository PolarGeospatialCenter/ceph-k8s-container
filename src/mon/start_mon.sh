#!/bin/bash
set -e
v6regexp="^[a-fA-F0-9]{1,4}:.*:[a-fA-F0-9]{1,4}$"

function start_mon {
  # Required Vars
  : "${MON_ID?}"
  : "${MON_CLUSTER_START_EPOCH?}"

  IP=`hostname -i`
  echo $IP
  # Run checks for keyring and ceph-conf.
  #touch /etc/ceph/ceph.conf

  # Error if mon data directory does not exist.
  if [ ! -e "$MON_DATA_DIR/keyring" ]; then
    log "Monitor data directory does not exist, exiting..."
    exit 1
  fi

  # Error if mon data directory does not exist.
  if [ ! -e "$MON_CONFIGMAP" ]; then
    log "Monitor cluster configmap does not exist, exiting..."
    exit 1
  fi

  FSID=$(ceph-conf --lookup fsid)

  config_start_epoch=$(jq .startEpoch $MON_CONFIGMAP)
  log "Waiting for $MON_CONFIGMAP correct start epoch to equal $MON_CLUSTER_START_EPOCH, current start epoch $config_start_epoch"
  while [[ $config_start_epoch -ne $MON_CLUSTER_START_EPOCH ]] ; do
    sleep 1
    config_start_epoch=$(jq .startEpoch $MON_CONFIGMAP)
    log "Waiting 1s for the correct start epoch, current start epoch $config_start_epoch"
  done

  # Update our monmap
  monmap_exists=$(ceph-monstore-tool /mon/data get monmap -- --out /tmp/monmap  2> /dev/null > /dev/null)$? || true
  # If monmap exists, update
  if [[ $monmap_exists -ne 0 ]] ; then
    monmaptool --create --fsid $FSID /tmp/monmap
  fi

  for k in $(jq  '.monMap | keys | .[]' $MON_CONFIGMAP); do
    map_id=$(jq -r ".monMap[$k].id" $MON_CONFIGMAP)
    map_port=$(jq -r ".monMap[$k].port" $MON_CONFIGMAP)
    map_ip=$(jq -r ".monMap[$k].ip" $MON_CONFIGMAP)
    if [[ ${map_ip} =~ $v6regexp ]]; then
      map_ip="[${map_ip}]"
    fi

    mon_in_monmap=$(monmaptool --clobber --rm $map_id "/tmp/monmap")$? || true
    monmaptool --clobber --add $map_id  $map_ip:$map_port  "/tmp/monmap"
  done

  mon_in_monmap=$(monmaptool --clobber --rm $MON_ID "/tmp/monmap")$? || true
  monmaptool --clobber --add $MON_ID  $MON_IP:6789  "/tmp/monmap"

  /usr/bin/ceph-mon "${DAEMON_OPTS[@]}" -i "${MON_ID}" --inject-monmap /tmp/monmap --mon-data "$MON_DATA_DIR" --public-addr $IP


  # Do we need to be in MON_CONFIGMAP?  If we aren't we've never joined.
  quorum=$(timeout 5 ceph "${CLI_OPTS[@]}" mon dump 2> /dev/null > /dev/null)$? || true
  log "Check for quorum returned $quorum"
  # If quorum add monitor
  if [[ $quorum -eq 0 ]] ; then
    log "Quorum exists, adding monitor to online cluster."

    currentMap=$(timeout 5 ceph "${CLI_OPTS[@]}" mon dump)
    log "Current map: $currentMap"

    monrmstatus=$(timeout 7 ceph "${CLI_OPTS[@]}" mon rm $MON_ID)$? || true
    if [[ $monrmstatus -ne 0 ]]; then
      log "Failed to remove monitor from existing cluster, returned $monrmstatus"
    fi

    if [[ ${MON_IP} =~ $v6regexp ]]; then
      MON_IP="[${MON_IP}]"
    fi

    timeout 7 ceph "${CLI_OPTS[@]}" mon add "${MON_ID}" "${MON_IP}:6789"
  fi

  # start MON
  log "Starting Ceph-Mon"
  #while true; do sleep 2; done
  exec /usr/bin/ceph-mon "${DAEMON_OPTS[@]}" -i "${MON_ID}" --mon-data "$MON_DATA_DIR" --public-addr $IP
}
