#!/bin/bash
set -e

function start_osd {
  log "Activating on OSD device"
  #ceph-volume lvm activate $OSD_ID $OSD_UUID --no-systemd
  mkdir /ceph-osd
  ceph-bluestore-tool --cluster=ceph prime-osd-dir --dev /dev/osd --path /ceph-osd

  OSD_ID=$(cat /ceph-osd/whoami)
  log "Getting our osd key using admin keyring... This is stupid..."
  ceph auth export osd.${OSD_ID} > /ceph-osd/keyring
  chown -R ceph:ceph /ceph-osd
  chown ceph:ceph /dev/osd

  log "Starting OSD daemon for OSD.$OSD_ID"
  #ceph-osd -f -i "${OSD_ID}" --setuser ceph --setgroup disk
  ceph-osd -d -i ${OSD_ID} --keyring /ceph-osd/keyring -n osd.${OSD_ID} --setuser ceph --setgroup disk --osd-data /ceph-osd/
}
