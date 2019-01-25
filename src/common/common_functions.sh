#!/bin/bash
set -e

# log arguments with timestamp
function log {
  if [ -z "$*" ]; then
    return 1
  fi

  local timestamp
  timestamp=$(date '+%F %T')
  echo "$timestamp  $0: $*"
  return 0
}

function create_mandatory_directories {

  for keyring in $OSD_BOOTSTRAP_KEYRING $MDS_BOOTSTRAP_KEYRING $RGW_BOOTSTRAP_KEYRING $RBD_MIRROR_BOOTSTRAP_KEYRING; do
    mkdir -p "$(dirname "$keyring")"
  done

  # Let's create the ceph directories
  for directory in mon osd mds radosgw tmp mgr; do
   mkdir -p /var/lib/ceph/$directory
  done

  # Make the monitor directory
  mkdir -p "$MON_DATA_DIR"
  chown "${CHOWN_OPT[@]}" -R ceph. $MON_DATA_DIR

  # Create socket directory
  mkdir -p /var/run/ceph

  # Adjust the owner of all those directories
  chown "${CHOWN_OPT[@]}" -R ceph. /var/run/ceph/
  find -L /var/lib/ceph/ -mindepth 1 -maxdepth 3 -exec chown "${CHOWN_OPT[@]}" ceph. {} \;
}

# Transform any set of strings to lowercase
function to_lowercase {
  echo "${@,,}"
}

# Transform any set of strings to uppercase
function to_uppercase {
  echo "${@^^}"
}

function invalid_cmd {
  if [ -z "$CMD" ]; then
    log "ERROR: One of CMD or a cmd parameter must be defined as the name of the cmd you want to deploy."
    valid_cmd
    exit 1
  else
    log "ERROR: Unrecognized CMD."
    valid_cmd
  fi
}

function valid_cmd {
  log "Valid values for CMD are $(to_uppercase "$ALL_CMDS")."
}

# ceph config file exists or die
function check_config {
  if [[ ! -e /etc/ceph/$CLUSTER.conf ]]; then
    log "ERROR- /etc/ceph/$CLUSTER.conf must exist; get it from your existing mon"
    exit 1
  fi
}
