.PHONY: image
image:
	docker build -t lcr.loongnix.cn/library/postgres:18.3-forky -t lcr.loongnix.cn/library/postgres:18-forky .

.PHONY: push
push:
	docker push lcr.loongnix.cn/library/postgres:18.3-forky
	docker push lcr.loongnix.cn/library/postgres:18-forky
