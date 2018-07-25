FROM polargeospatialcenter/ceph-base

#ADD test/etc-ceph/* /etc/ceph/

COPY src /ceph
COPY qtainer /bin

VOLUME ["/etc/ceph"]

WORKDIR /ceph
ENTRYPOINT ["sh","entrypoint.sh"]
