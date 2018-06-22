#!/bin/bash
set -e

function prepare_osd {
  #Required Vars
  : "${OSD_DEVICE?}"
  : "${OSD_ZAP?}"

  log "Editing lvm.conf..."
  sed -i 's/udev_sync = 1/udev_sync = 0/g; s/udev_rules = 1/udev_rules = 0/' /etc/lvm/lvm.conf

  if [ ! -f "/var/lib/ceph/bootstrap-osd/ceph.keyring" ]; then
    log "Error: Ceph keyring does not exist."
    exit 1
  fi

  if [ "$OSD_ZAP" == "true" ]; then
    log "Zapping OSD device $OSD_DEVICE"
    ceph-volume lvm zap $OSD_DEVICE --destroy
  fi

  log "Starting prepare on OSD device $OSD_DEVICE"
  ceph-volume lvm prepare --bluestore --data $OSD_DEVICE
  exit 0
}
