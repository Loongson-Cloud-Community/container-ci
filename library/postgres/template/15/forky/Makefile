.PHONY: image
image:
	docker build -t lcr.loongnix.cn/library/postgres:15.17-forky -t lcr.loongnix.cn/library/postgres:15-forky .

.PHONY: push
push:
	docker push lcr.loongnix.cn/library/postgres:15.17-forky
	docker push lcr.loongnix.cn/library/postgres:15-forky
