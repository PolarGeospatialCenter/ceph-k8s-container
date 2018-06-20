.PHONY: all

all: docker push

docker:
	docker build -t janse180/ceph-k8s-container:latest .

push:
	docker push janse180/ceph-k8s-container:latest
