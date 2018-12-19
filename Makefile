.PHONY: all

all: docker push

docker:
	docker build -t pgc-docker.artifactory.umn.edu/ceph-k8s-container:latest .

push:
	docker push pgc-docker.artifactory.umn.edu/ceph-k8s-container:latest
