#!/bin/bash
set -e

ALL_CMDS="mon mgr"

#########################
# REQUIRED VARIABLES #
#########################


#########################
# LIST OF ALL VARIABLES #
#########################

HOSTNAME=$(uname -n | cut -d'.' -f1)
: "${CMD:=${1}}" # default cmd to first argument
: "${RGW_NAME:=${HOSTNAME}}"
: "${RBD_MIRROR_NAME:=${HOSTNAME}}"
: "${MGR_NAME:=${HOSTNAME}}"
: "${MDS_NAME:=${HOSTNAME}}"
: "${CLUSTER:=ceph}"
: "${MON_DATA_DIR:=/var/lib/ceph/mon/${CLUSTER}}"
: "${MON_HISTORY_DIR:=${MON_DATA_DIR}/history}"
: "${CEPH_CLUSTER_NETWORK:=${CEPH_PUBLIC_NETWORK}}"
: "${K8S_HOST_NETWORK:=0}"
: "${K8S_MON_SELECTOR:=app=ceph,daemon=mon}"
: "${MON_MAP:=/tmp/ceph/monmap-${CLUSTER}}"

# This is ONLY used for the daemon's startup, e.g: ceph-osd $DAEMON_OPTS
DAEMON_OPTS=(--cluster ${CLUSTER} --setuser ceph --setgroup ceph -d)

# Internal variables
ADMIN_KEYRING=/keyrings/client-admin/keyring
MON_BOOTSTRAP_KEYRING=/keyrings/mon-bootstrap/keyring
MON_KEYRING=/tmp/ceph/mon/${CLUSTER}-${MON_NAME}/keyring
MDS_KEYRING=/tmp/ceph/mds/${CLUSTER}-${MDS_NAME}/keyring
RGW_KEYRING=/tmp/ceph/radosgw/${CLUSTER}-rgw.${RGW_NAME}/keyring
MDS_BOOTSTRAP_KEYRING=/tmp/ceph/bootstrap-mds/${CLUSTER}.keyring
RGW_BOOTSTRAP_KEYRING=/tmp/ceph/bootstrap-rgw/${CLUSTER}.keyring
OSD_BOOTSTRAP_KEYRING=/tmp/ceph/bootstrap-osd/${CLUSTER}.keyring
RBD_MIRROR_BOOTSTRAP_KEYRING=/tmp/ceph/bootstrap-rbd/${CLUSTER}.keyring
MGR_KEYRING=/var/lib/ceph/mgr/${CLUSTER}-${MGR_NAME}/keyring
RBD_MIRROR_KEYRING=/tmp/ceph/${CLUSTER}.client.rbd-mirror.${HOSTNAME}.keyring
OSD_PATH_BASE=/var/lib/ceph/osd/${CLUSTER}

# This is ONLY used for the CLI calls, e.g: ceph $CLI_OPTS health
CLI_OPTS=(--cluster ${CLUSTER} --keyring ${ADMIN_KEYRING})
