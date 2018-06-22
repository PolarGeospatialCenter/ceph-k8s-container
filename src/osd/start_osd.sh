#!/bin/bash
set -e

function start_osd {
  #Required Vars
  : "${OSD_ID?}"
  : "${OSD_UUID?}"

  log "Editing lvm.conf..."
  sed -i 's/udev_sync = 1/udev_sync = 0/g; s/udev_rules = 1/udev_rules = 0/' /etc/lvm/lvm.conf

  log "Scanning Volume Groups..."
  vgscan --mknodes

  log "Activating on OSD device $OSD_ID"
  ceph-volume lvm activate $OSD_ID $OSD_UUID --no-systemd

  log "Starting OSD daemon for OSD.$OSD_ID"
  ceph-osd -f -i "${OSD_ID}" --setuser ceph --setgroup disk
}
