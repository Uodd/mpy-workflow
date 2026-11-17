# MicroPython workflow for ESP32
# Override any variable on the command line, e.g.:
#   make flash PORT=/dev/ttyUSB1 BIN=mpBin/other.bin

# ---- Configuration -----------------------------------------------------------
PORT   ?= /dev/ttyUSB0
BIN    ?= $(firstword $(wildcard mpBin/*.bin))
CHIP   ?= esp32
BAUD   ?= 460800
# Flash offset: 0x1000 for ESP32, 0x0 for ESP32-S3/C3/C6
OFFSET ?= 0x1000
SRC    ?= src
# For push/pull/rm/run of a single file
FILE   ?=
DEST   ?= .

VENV     := .venv
ESPTOOL  := $(VENV)/bin/esptool
MPREMOTE := $(VENV)/bin/mpremote
MP       := $(MPREMOTE) connect $(PORT)

.DEFAULT_GOAL := help
.PHONY: help install ports info erase write flash repl ls push pull rm run reset tree

help: ## Show this help
	@echo "Usage: make <target> [PORT=$(PORT)] [BIN=$(BIN)]"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-13s\033[0m %s\n", $$1, $$2}'

install: ## Create venv and install requirements
	test -d $(VENV) || python3 -m venv $(VENV)
	$(VENV)/bin/pip install -r requirements.txt

ports: ## List available serial ports
	@$(MPREMOTE) devs | grep -v '^/dev/ttyS'

# ---- Flashing (esptool) ------------------------------------------------------
info: ## Show chip and flash info
	$(ESPTOOL) --chip $(CHIP) --port $(PORT) flash-id

erase: ## Erase the whole flash
	$(ESPTOOL) --chip $(CHIP) --port $(PORT) erase-flash

write: _check-bin ## Write BIN to flash (no erase)
	$(ESPTOOL) --chip $(CHIP) --port $(PORT) --baud $(BAUD) write-flash -z $(OFFSET) $(BIN)

flash: erase write ## Erase flash and write MicroPython BIN

_check-bin:
	@test -n "$(BIN)" -a -f "$(BIN)" || { echo "Error: BIN not found ('$(BIN)'). Set BIN=path/to/firmware.bin"; exit 1; }

# ---- Files & REPL (mpremote) -------------------------------------------------
repl: ## Open the REPL (exit with Ctrl-])
	$(MP) repl

ls: ## List files on device root
	$(MP) fs ls :

tree: ## Show device filesystem tree
	$(MP) fs tree :

push: ## Upload FILE (or the whole SRC dir if FILE empty) to device root
ifeq ($(strip $(FILE)),)
	@test -n "$(wildcard $(SRC)/*)" || { echo "Nothing to push: $(SRC)/ is empty"; exit 1; }
	$(MP) fs cp -r $(wildcard $(SRC)/*) :
else
	$(MP) fs cp $(FILE) :$(notdir $(FILE))
endif

pull: ## Download FILE from device into DEST (default .), e.g. make pull FILE=main.py DEST=src/
	@test -n "$(FILE)" || { echo "Usage: make pull FILE=<device path> [DEST=<local dir>]"; exit 1; }
	$(MP) fs cp -r :$(FILE) $(DEST)

rm: ## Remove FILE from device
	@test -n "$(FILE)" || { echo "Usage: make rm FILE=<device path>"; exit 1; }
	$(MP) fs rm -r :$(FILE)

run: ## Run local FILE on device without copying it
	@test -n "$(FILE)" || { echo "Usage: make run FILE=<local .py>"; exit 1; }
	$(MP) run $(FILE)

reset: ## Soft-reset the device
	$(MP) soft-reset
