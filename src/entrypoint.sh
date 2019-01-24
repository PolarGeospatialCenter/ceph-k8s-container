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
  start_mon)
    # Launch Monitor
    source mon/start_mon.sh
    start_mon
    ;;
  prepare_mon)
    # Launch Monitor
    source mon/prepare_mon.sh
    prepare_mon
    ;;
  start_mgr)
    # Launch MGR
    source mgr/start_mgr.sh
    start_mgr
    ;;
  start_mds)
    # Launch Monitor
    source mds/start_mds.sh
    start_mds
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
  sync_keyrings)
    # Sync Keyrings
    source keyrings/sync_keyrings.sh
    sync_keyrings
    ;;
  debug)
    # Run a loop for debugging.
    while true; do sleep 2; done
    ;;
  *)
    log "Error: Please specficy a valid command: got $CMD"
    exit 1
    ;;
esac

exit 0
