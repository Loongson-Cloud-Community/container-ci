image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/ruby:3.3.3-trixie \
		-t lcr.loongnix.cn/library/ruby:3.3.3 \
		.

push:
	docker push lcr.loongnix.cn/library/ruby:3.3.3-trixie
	docker push lcr.loongnix.cn/library/ruby:3.3.3

