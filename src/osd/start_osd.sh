#!/bin/bash
set -e

function start_osd {
  #Required Vars
  : "${OSD_ID?}"
  : "${OSD_UUID?}"

  log "Activating on OSD device $OSD_ID"
  ceph-volume lvm activate $OSD_ID $OSD_UUID --no-systemd

  log "Starting OSD daemon for OSD.$OSD_ID"
  ceph-osd -f -i "${OSD_ID}" --setuser ceph --setgroup disk
}
