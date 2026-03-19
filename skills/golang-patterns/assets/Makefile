.PHONY: tests format vet docker-setup docker-stop lint

tests:
	go test ./... -v -coverprofile=coverage.out

format:
	find . -name '*.go' -exec goimports -w {} +
	golangci-lint run --fix

vet:
	go vet ./...

lint:
	golangci-lint run --timeout=5m

docker-setup:
	docker compose up -d --remove-orphans --force-recreate

docker-stop:
	docker compose down
