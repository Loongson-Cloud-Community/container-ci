org:=prometheus
proj:=pushgateway

image:
	docker build \
		-t lcr.loongnix.cn/$(org)/$(proj):1.11.3-distroless \
		.

push:
	docker push lcr.loongnix.cn/$(org)/$(proj):1.11.3-distroless

