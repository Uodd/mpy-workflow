# MicroPython workflow for ESP32
# Override any variable on the command line, e.g.:
#   make flash PORT=/dev/ttyUSB1 BIN=mpBin/other.bin

# ---- Configuration -----------------------------------------------------------
# Personal settings (not committed): put e.g. BIN = mpBin/xxx.bin in local.mk
-include local.mk

PORT   ?= /dev/ttyUSB0
# Firmware to flash: set it here or pass it at runtime (make flash BIN=mpBin/xxx.bin)
BIN    ?=
CHIP   ?= esp32
BAUD   ?= 460800
# Flash offset: 0x1000 for ESP32, 0x0 for ESP32-S3/C3/C6
OFFSET ?= 0x1000
SRC    ?= src
# Local folder where make pull saves files from the board
PULL_DIR ?= pulled
# For push/pull/rm/run of a single file
FILE   ?=
# For make mip: package name or URL
PKG    ?=

VENV     := .venv
ESPTOOL  := $(VENV)/bin/esptool
MPREMOTE := $(VENV)/bin/mpremote
MP       := $(MPREMOTE) connect $(PORT)

.DEFAULT_GOAL := help
.PHONY: help install ports bins info erase upgrade flash repl ls tree dev deploy push pull rm wipe run reset mip

help: ## Show this help
	@echo "Usage: make <target> [PORT=$(PORT)] [BIN=$(BIN)]"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(firstword $(MAKEFILE_LIST)) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-13s\033[0m %s\n", $$1, $$2}'

install: ## Create venv and install requirements
	test -d $(VENV) || python3 -m venv $(VENV)
	$(VENV)/bin/pip install -r requirements.txt

ports: ## List available serial ports
	@$(MPREMOTE) devs | grep -v '^/dev/ttyS'

# ---- Flashing (esptool) ------------------------------------------------------
bins: ## List firmware files in mpBin/
	@ls -1 mpBin/*.bin 2>/dev/null || echo "No .bin files in mpBin/"

# esptool resets the board when it finishes. Wait for it to boot so a following
# mpremote command (e.g. make info ls) can connect.
BOOT_WAIT = @sleep 2

info: ## Show chip and flash info
	$(ESPTOOL) --chip $(CHIP) --port $(PORT) flash-id
	$(BOOT_WAIT)

erase: ## Erase the whole flash
	$(ESPTOOL) --chip $(CHIP) --port $(PORT) erase-flash
	$(BOOT_WAIT)

WRITE_FW = $(ESPTOOL) --chip $(CHIP) --port $(PORT) --baud $(BAUD) write-flash -z $(OFFSET) $(BIN)

upgrade: _check-bin ## Write firmware without erasing (files on the board are usually kept)
	$(WRITE_FW)
	$(BOOT_WAIT)

flash: _check-bin erase ## Clean install: erase everything, then write firmware
	$(WRITE_FW)
	$(BOOT_WAIT)

_check-bin:
	@if [ -z "$(BIN)" ]; then echo "Error: BIN not set. Use: make $(or $(MAKECMDGOALS),flash) BIN=mpBin/<file>.bin"; echo "Available:"; $(MAKE) -s bins; exit 1; fi
	@test -f "$(BIN)" || { echo "Error: '$(BIN)' not found"; exit 1; }

# ---- Files & REPL (mpremote) -------------------------------------------------
repl: ## Open the REPL (exit with Ctrl-])
	$(MP) repl

ls: ## List files on device root
	$(MP) fs ls :

tree: ## Show device filesystem tree
	$(MP) fs tree :

KEYS_HINT = @echo "Keys: Ctrl-C stops the program (then Ctrl-B for the >>> prompt), Ctrl-X exits"

dev: ## Run SRC/main.py straight from your computer, nothing copied
	$(KEYS_HINT)
	@echo "To rerun after editing: exit and run make dev again (Ctrl-D doesn't work in dev)"
	$(MP) mount $(SRC) exec --no-follow "import main" repl

deploy: push ## Push SRC, restart the board and open the REPL to watch main.py
	$(MP) reset
	$(MP) repl

push: ## Upload FILE (or the whole SRC dir if FILE empty) to device root
ifeq ($(strip $(FILE)),)
	@test -n "$(wildcard $(SRC)/*)" || { echo "Nothing to push: $(SRC)/ is empty"; exit 1; }
	$(MP) fs cp -r $(wildcard $(SRC)/*) :
else
	$(MP) fs cp $(FILE) :$(notdir $(FILE))
endif

pull: ## Download FILE (or the whole board if FILE empty) into PULL_DIR, keeping folders
ifeq ($(strip $(FILE)),)
	mkdir -p $(PULL_DIR)
	$(MP) fs cp -r : $(PULL_DIR)/
else
	mkdir -p $(PULL_DIR)/$(dir $(FILE))
	$(MP) fs cp -r :$(FILE) $(PULL_DIR)/$(dir $(FILE))
endif

rm: ## Remove FILE from device
	@test -n "$(FILE)" || { echo "Usage: make rm FILE=<device path>"; exit 1; }
	$(MP) fs rm -r :$(FILE)

wipe: ## Delete all files on the board except boot.py (asks first)
	@files=$$($(MP) exec "import os; print(' '.join(':' + f for f in os.listdir('/') if f != 'boot.py'))" | tr -d '\r'); \
	if [ -z "$$files" ]; then echo "Nothing to delete"; exit 0; fi; \
	echo "Will delete on $(PORT): $$(echo $$files | tr -d :)"; \
	read -p "Continue? [y/N] " ans; [ "$$ans" = y ] || { echo "Aborted"; exit 0; }; \
	$(MP) fs rm -r $$files

run: ## Run local FILE on device without copying it
	@test -n "$(FILE)" || { echo "Usage: make run FILE=<local .py>"; exit 1; }
	$(KEYS_HINT)
	$(MP) run --no-follow $(FILE) repl

reset: ## Restart the board (runs boot.py and main.py)
	$(MP) reset

mip: ## Install a MicroPython package into /lib, e.g. make mip PKG=aioble
	@test -n "$(PKG)" || { echo "Usage: make mip PKG=<package name or URL>"; exit 1; }
	$(MP) mip install $(PKG)
