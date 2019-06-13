#!/bin/bash
set -e
OSD_DEVICE=/dev/osd

function overprovision_ssd {
  hdparmOutput=$(hdparm -N $OSD_DEVICE 2>/dev/null || echo -n "")
  if [[ $hdparmOutput == "" ]]; then
    log "HDParm returned error or nothing, assuming regular hdd"
    return 0
  fi

  availableSize=$(printf "$hdparmOutput" | gawk '{if (match($0, /([0-9]+)\/([0-9]+), HPA/, arr)){ print arr[1] }}')
  totalSize=$(printf "$hdparmOutput" | gawk '{if (match($0, /([0-9]+)\/([0-9]+), HPA/, arr)){ print arr[2] }}')
  if [ $availableSize -eq $totalSize ]; then
    if [[ "$OSD_ZAP" == "true" ]]; then
      log "Attempting to overprovision ssd, reboot required to take effect"
      newAvailableSize=$(($totalSize * 1024/1000 * 3/4))
      hdparm -Np$newAvailableSize --yes-i-know-what-i-am-doing $OSD_DEVICE
      availableSize=$newAvailableSize
    fi
  fi

  currentReportedSize=$(blockdev --getsize $OSD_DEVICE)
  if [ $availableSize -eq $currentReportedSize ]; then
    return 0
  fi


  return 2
}

function prepare_osd {
  : "${OSD_ZAP?}"
  : "${CLUSTER?}"
  : "${CLUSTER_NAMESPACE?}"
  : "${PV_LABEL_SELECTOR?}"
  : "${DISABLED:=false}"
  : "${OVERPROVISION:=true}"

  if [ "$OVERPROVISION" == "true" ]; then
    if ! overprovision_ssd ; then
      log "SSD Not Overprovisioned"
      exit 1
    fi
  fi

  log "contents of /etc/ceph/$CLUSTER.conf"
  cat /etc/ceph/$CLUSTER.conf

  if [ "$OSD_ZAP" == "true" ]; then
    log "Zapping OSD device $OSD_DEVICE"
    wipefs -a --force $OSD_DEVICE
    dd if=/dev/zero of=$OSD_DEVICE count=5k bs=1k
  fi

  /ceph/bin/write-crush-location-file.sh

  UUID=$(uuidgen)
  OSD_SECRET=$(ceph-authtool --gen-print-key)
  OSD_ID=$(echo "{\"cephx_secret\": \"$OSD_SECRET\"}" | \
      ceph --cluster $CLUSTER osd new $UUID -i - -n client.bootstrap-osd -k /keyrings/client.bootstrap-osd/keyring)

  mkdir /ceph-osd
  chown ceph:ceph /ceph-osd

  ln -s /dev/osd /ceph-osd/block
  log "Creating keyring for OSD"
  ceph-authtool --cluster $CLUSTER --create-keyring /ceph-osd/keyring --name osd.$OSD_ID --add-key $OSD_SECRET
  log "Initializing OSD"
  ceph-osd --cluster $CLUSTER --osd-objectstore bluestore --mkfs -i $OSD_ID --osd-data /ceph-osd/ --osd-uuid $UUID --keyring /ceph-osd/keyring --conf=/etc/ceph/ceph.conf
  log "Storing secret on OSD"
  ceph-bluestore-tool set-label-key -k osd_key -v $OSD_SECRET --dev /dev/osd
  chown -R ceph:ceph /ceph-osd/

  cat << EOF > /tmp/osd.yaml
apiVersion: ceph.k8s.pgc.umn.edu/v1alpha1
kind: CephOsd
metadata:
  name: $CLUSTER-osd.$OSD_ID
  namespace: $CLUSTER_NAMESPACE
spec:
  clusterName: $CLUSTER
  id: $OSD_ID
  pvSelectorString: $PV_LABEL_SELECTOR
  disabled: $DISABLED
EOF

  kubectl apply -f /tmp/osd.yaml
}
