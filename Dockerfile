FROM polargeospatialcenter/ceph-base

#ADD test/etc-ceph/* /etc/ceph/

ADD *.sh /ceph/

VOLUME ["/etc/ceph"]

WORKDIR /ceph
ENTRYPOINT ["/ceph/entrypoint.sh"]
