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
  activate_osd
  #ceph-volume lvm activate $OSD_ID $OSD_UUID --no-systemd

  log "Starting OSD daemon for OSD.$OSD_ID"
  ceph-osd -f -i "${OSD_ID}" --setuser ceph --setgroup disk
}

function activate_osd {
  DEV_PATH=$(find /dev -name osd-block-$OSD_UUID)
  OSD_PATH=/var/lib/ceph/osd/ceph-$OSD_ID
  mkdir -p $OSD_PATH
  ceph-bluestore-tool --no-mon-config prime-osd-dir --dev $DEV_PATH --path $OSD_PATH
  ln -snf $DEV_PATH $OSD_PATH
  chown -R ceph:ceph $(realpath $DEV_PATH)
  chown -R ceph:ceph $OSD_PATH
}
