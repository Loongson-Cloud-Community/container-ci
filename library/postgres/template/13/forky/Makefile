.PHONY: image
image:
	docker build -t lcr.loongnix.cn/library/postgres:13.23-forky -t lcr.loongnix.cn/library/postgres:13-forky .

.PHONY: push
push:
	docker push lcr.loongnix.cn/library/postgres:13.23-forky
	docker push lcr.loongnix.cn/library/postgres:13-forky
