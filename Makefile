.PHONY: build push

all: build

build: Dockerfile
	docker build -t schlomo/ntopng-docker .
