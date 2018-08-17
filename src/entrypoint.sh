#!/bin/sh
set -e
export LC_ALL=C
export PATH=$PATH:/ceph

source common/variables_entrypoint.sh
source common/common_functions.sh

create_mandatory_directories

# Normalize CMD to lowercase
CMD=$(to_lowercase "${CMD}")

case "$CMD" in
  mon)
    # Launch Monitor
    source mon/start_mon.sh
    start_mon
    ;;
  mgr)
    # Launch MGR
    source mgr/start_mgr.sh
    start_mgr
    ;;
  prepare_osd)
    # Launch Prepare
    source osd/prepare_osd.sh
    prepare_osd
    ;;
  start_osd)
    # Launch OSD
    source osd/start_osd.sh
    start_osd
    ;;
  debug)
    # Run a loop for debugging.
    while true; do sleep 2; done
    ;;
  *)
    log "Error: Please specficy a valid command."
    exit 1
    ;;
esac

exit 0
