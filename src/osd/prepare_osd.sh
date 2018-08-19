#!/bin/bash
set -e

function prepare_osd {
  OSD_DEVICE=/dev/osd
  # Exit if disk not overprovisioned
  hdparmOutput=$(hdparm -N $OSD_DEVICE 2>/dev/null || echo -n "")
  printf "$hdparmOutput" | gawk '{if (match($0, /([0-9]+)\/([0-9]+), HPA/, arr)){if (arr[1] == arr[2]){print "Disk not overprovisioned"; exit 1} }}' || exit 1

  UUID=$(uuidgen)
  OSD_SECRET=$(ceph-authtool --gen-print-key)
  OSD_ID=$(echo "{\"cephx_secret\": \"$OSD_SECRET\"}" | \
      ceph osd new $UUID -i - -n client.bootstrap-osd -k /var/lib/ceph/bootstrap-osd/ceph.keyring)

  mkdir /ceph-osd
  chown ceph:ceph /ceph-osd

  ln -s /dev/osd /ceph-osd/block
  ceph-authtool --create-keyring /ceph-osd/keyring --name osd.$ID --add-key $OSD_SECRET
  ceph-osd --cluster ceph --osd-objectstore bluestore --mkfs -i $ID --osd-data /ceph-osd/ --osd-uuid $UUID --keyring /ceph-osd/keyring
  chown -R ceph:ceph /ceph-osd/
}
