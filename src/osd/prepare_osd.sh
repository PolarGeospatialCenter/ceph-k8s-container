#!/bin/bash
set -e

function prepare_osd {
  #Required Vars
  : "${OSD_DEVICE?}"
  : "${OSD_ZAP?}"
  : "${K8S_DISK_NAME}"

  log "Editing lvm.conf..."
  sed -i 's/udev_sync = 1/udev_sync = 0/g; s/udev_rules = 1/udev_rules = 0/' /etc/lvm/lvm.conf

  find /sys/block/sd* |xargs -n 1 udevadm test > /dev/null 2>&1
  OSD_DEVICE=$(realpath $OSD_DEVICE)

  #Check if OSD is already prepared.
  get_osd_info && sync_osd_info && exit 0 || log "No existing OSD found"

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

  get_osd_info && sync_osd_info
  exit 0
}

function get_osd_info {
  vgscan --mknodes
  VG_NAME=$(pvs --no-headings $OSD_DEVICE -o vg_name |xargs) || return 1
  LV_NAME=$(lvs --no-headings $VG_NAME -o lv_name |xargs) || return 1
  JSON=$(ceph-bluestore-tool show-label --dev /dev/$VG_NAME/$LV_NAME) || return 1

  UUID=$(echo $JSON |jq '.[].osd_uuid' -r) || return 1
  ID=$(echo $JSON |jq '.[].whoami' -r) || return 1

  return 0
}

function sync_osd_info {
  kubectl get disk $K8S_DISK_NAME -o json |jq '.osdInfo.id=env.ID | .osdInfo.uuid=env.UUID' | kubectl apply -f -
}
