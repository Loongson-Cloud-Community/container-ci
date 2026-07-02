image:
	docker build \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/rust:1.96.1-forky-slim \
		.

push:
	docker push lcr.loongnix.cn/library/rust:1.96.1-forky-slim

