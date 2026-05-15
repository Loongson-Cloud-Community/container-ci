.PHONY: image
image:
	docker build -t lcr.loongnix.cn/library/postgres:16.14-forky -t lcr.loongnix.cn/library/postgres:16-forky .

.PHONY: push
push:
	docker push lcr.loongnix.cn/library/postgres:16.14-forky
	docker push lcr.loongnix.cn/library/postgres:16-forky
