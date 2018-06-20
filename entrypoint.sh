#!/bin/sh
set -e
export LC_ALL=C

source /ceph/variables_entrypoint.sh
source /ceph/common_functions.sh

create_mandatory_directories

# Normalize CMD to lowercase
CMD=$(to_lowercase "${CMD}")

case "$CMD" in
  mon)
    # Launch Monitor
    source /ceph/start_mon.sh
    start_mon
    ;;
  *)
    log "Error: Please specficy a valid command."
    exit 1
    ;;
esac

exit 0
