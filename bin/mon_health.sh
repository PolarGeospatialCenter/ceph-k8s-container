#! /bin/bash
set -e

#Require mon name
: "${MON_ID?}"

#Connect to admin socket and get state
state=$(timeout 5 ceph daemon mon.$MON_ID mon_status |jq -r .state)

#Check if state is valid.
if [ "$state" = "leader" ] || [ "$state" = "peon" ]; then
  exit 0
fi

exit 1
