# Dynamo Demo Server -- one command: `make server`.
#
# Clones ai-dynamo/dynamo (main) into ./.dynamo (gitignored) and builds the
# release binary. After that, run ./target/release/dynamo-demo-server with
# whatever flags you want (see --help).
#
# Override the source: `make server DYNAMO_SRC=/path/to/dynamo` (symlinks
# instead of cloning).

DYNAMO_REPO ?= https://github.com/ai-dynamo/dynamo.git
DYNAMO_REF  ?= main
DYNAMO_SRC  ?=
DYNAMO_DIR  := .dynamo

.DEFAULT_GOAL := server

$(DYNAMO_DIR)/Cargo.toml:
	@if [ -n "$(DYNAMO_SRC)" ]; then \
		echo ">>> linking $(DYNAMO_SRC) -> $(DYNAMO_DIR)"; \
		ln -sfn "$(DYNAMO_SRC)" $(DYNAMO_DIR); \
	else \
		echo ">>> cloning $(DYNAMO_REPO) ($(DYNAMO_REF)) -> $(DYNAMO_DIR)"; \
		git clone --depth 1 --branch $(DYNAMO_REF) $(DYNAMO_REPO) $(DYNAMO_DIR); \
	fi

.PHONY: server
server: $(DYNAMO_DIR)/Cargo.toml
	cargo build --release
	@echo
	@echo ">>> built. run the server:"
	@echo "    cargo run --release -- --model Qwen/Qwen2.5-0.5B-Instruct"
	@echo
	@echo ">>> all flags:"
	@echo "    cargo run --release -- --help"

.PHONY: clean
clean:
	cargo clean
	rm -rf $(DYNAMO_DIR)
