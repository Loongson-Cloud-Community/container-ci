.PHONY: image
image:
	docker build -t lcr.loongnix.cn/library/postgres:14.25-forky -t lcr.loongnix.cn/library/postgres:14-forky .

.PHONY: push
push:
	docker push lcr.loongnix.cn/library/postgres:14.25-forky
	docker push lcr.loongnix.cn/library/postgres:14-forky
