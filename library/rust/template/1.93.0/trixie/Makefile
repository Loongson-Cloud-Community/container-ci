image:
	docker build \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/rust:1.93.0-trixie \
		-t lcr.loongnix.cn/library/rust:1.93.0 \
		.

push:
	docker push lcr.loongnix.cn/library/rust:1.93.0-trixie
	docker push lcr.loongnix.cn/library/rust:1.93.0

