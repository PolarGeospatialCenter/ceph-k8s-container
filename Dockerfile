FROM polargeospatialcenter/qtainer:latest

FROM polargeospatialcenter/ceph-base:latest

#ADD test/etc-ceph/* /etc/ceph/

COPY bin /ceph/bin
RUN chmod -R +x /ceph/bin

COPY src /ceph
COPY --from=0 /bin/qtainer /bin

VOLUME ["/etc/ceph"]

WORKDIR /ceph
ENTRYPOINT ["sh","entrypoint.sh"]
