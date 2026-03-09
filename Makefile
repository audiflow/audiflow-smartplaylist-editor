DATA_DIR ?= ../audiflow-smartplaylist
SERVER_PORT ?= 8080

.PHONY: dev-server dev-ui build test validate format

dev-server:
	cargo run -- serve --data-dir $(DATA_DIR) --port $(SERVER_PORT)

dev-ui:
	cd packages/sp_react && pnpm dev

build:
	pnpm --filter sp_react build
	cargo build --release

test:
	cargo test
	cd packages/sp_react && pnpm test

validate:
	cargo run -- validate --data-dir $(DATA_DIR)

format:
	cargo run -- format --data-dir $(DATA_DIR)
