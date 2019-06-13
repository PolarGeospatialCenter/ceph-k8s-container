#!/bin/bash
set -e

function start_osd {
  # Required Vars
  : "${CLUSTER?}"

  export CEPH_CONF=/etc/ceph/${CLUSTER}.conf

  log "Activating on OSD device"
  OSD_KEYRING="/ceph-osd/kerying"
  mkdir -p /keyrings/client.admin/
  touch /keyrings/client.admin/keyring
  #ceph-volume lvm activate $OSD_ID $OSD_UUID --no-systemd
  mkdir /ceph-osd
  ceph-bluestore-tool --cluster=$CLUSTER prime-osd-dir --dev /dev/osd --path /ceph-osd --no-mon-config

  if [[ ! -e /ceph-osd/whoami ]]; then
    log "No whoami file created.  Prime-osd-dir failed."
  fi

  OSD_ID=$(cat /ceph-osd/whoami)
  log "Found osd id: ${OSD_ID}"

  log "Building keyring from metadata on OSD"
  OSD_SECRET=$(ceph-bluestore-tool show-label --dev /dev/osd --no-mon-config | jq '."/dev/osd".osd_key' -r -e) || (log "Failed to get key from osd." && exit 1)
  ceph-authtool --create-keyring $OSD_KEYRING --name osd.$OSD_ID --add-key $OSD_SECRET \
    --cap mon 'allow profile osd' \
    --cap mgr 'allow profile osd' \
    --cap osd 'allow *'
  chown -R ceph:ceph /ceph-osd
  chown ceph:ceph /dev/osd

  /ceph/bin/write-crush-location-file.sh

  log "Starting OSD daemon for OSD.$OSD_ID"
  #ceph-osd -f -i "${OSD_ID}" --setuser ceph --setgroup disk
  ceph-osd "${DAEMON_OPTS[@]}" -i ${OSD_ID} --keyring /ceph-osd/keyring -n osd.${OSD_ID} --setgroup disk --osd-data /ceph-osd/
}
