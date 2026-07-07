org:=prometheus
proj:=prometheus

image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/$(org)/$(proj):3.13.0-distroless \
		.

push:
	docker push lcr.loongnix.cn/$(org)/$(proj):3.13.0-distroless

