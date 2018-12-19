#!/bin/bash

source /ceph/common/common_functions.sh
source /ceph/osd/prepare_osd.sh

for osd in $@; do
  OSD_DEVICE=$osd
  OSD_ZAP=true
  if overprovision_ssd ; then
    echo "$osd already overprovisioned"
  else
    echo "Overprovisioned $osd, reboot required"
  fi
done
