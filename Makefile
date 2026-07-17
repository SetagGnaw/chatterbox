APP := chatterbox
CHART := charts/chatterbox
DEV_VALUES := gitops/environments/dev/values.yaml
IMAGE ?= $(APP):local

.PHONY: test vet run build image helm-lint helm-template check bootstrap

test:
	go test ./...

vet:
	go vet ./...

run:
	go run ./cmd/server

build:
	go build -trimpath -o bin/server ./cmd/server

image:
	docker build --build-arg VERSION=local -t $(IMAGE) .

helm-lint:
	helm lint $(CHART) --values $(DEV_VALUES)

helm-template:
	helm template $(APP) $(CHART) \
		--namespace chatterbox-dev \
		--values $(DEV_VALUES) \
		> /tmp/chatterbox-rendered.yaml

check:
	./scripts/check.sh

bootstrap:
	./scripts/bootstrap.sh
