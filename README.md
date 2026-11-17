# MicroPython Workflow (ESP32)

A Makefile to flash MicroPython onto an ESP32 and manage files on the board, using `esptool` and `mpremote`.

## Setup

```sh
make install
```

This creates `.venv/` and installs the requirements. You don't need to activate the venv to use `make`.

Download a MicroPython firmware `.bin` for your board from <https://micropython.org/download/> and put it in `mpBin/`.

## Flash MicroPython

```sh
make ports    # find your board's serial port
make bins     # list the firmware files in mpBin/
make flash BIN=mpBin/ESP32_GENERIC-20260824-v1.29.0.bin
```

To avoid typing it every time, save it in `local.mk` (ignored by Git):

```sh
cp local.mk.example local.mk   # then set BIN in local.mk
make flash
```

`local.mk` can hold any other setting too, such as `PORT`. A value given on the command line still wins.

## Develop

```sh
make run FILE=src/main.py   # test a file without saving it to the board
make push                   # copy everything in src/ to the board
make repl                   # open the REPL (Ctrl-C stops the program, Ctrl-D restarts it, Ctrl-] exits)
```

`src/main.py` runs automatically every time the board boots.

## All commands

| Command | Description |
|---|---|
| `make install` | Create the venv and install requirements |
| `make ports` | List USB serial ports |
| `make bins` | List firmware files in `mpBin/` |
| `make info` | Show chip and flash info |
| `make erase` | Erase the whole flash |
| `make flash BIN=...` | Clean install: erase everything, then write the firmware |
| `make upgrade BIN=...` | Write the firmware without erasing; files on the board are usually kept (if the flash layout doesn't change) |
| `make repl` | Open the REPL |
| `make ls` / `make tree` | List files on the board |
| `make push` | Upload `src/` (or a single file with `FILE=`) |
| `make pull` | Download the whole board into `pulled/` (or a single file/folder with `FILE=`) |
| `make rm FILE=main.py` | Delete a file from the board |
| `make run FILE=src/x.py` | Run a local file without saving it |
| `make reset` | Soft-reset the board |

## Options

Change any setting on the command line, e.g. `make flash PORT=/dev/ttyUSB1`.

| Variable | Default | Notes |
|---|---|---|
| `PORT` | `/dev/ttyUSB0` | Serial port |
| `BIN` | (none) | Firmware file to flash, required by `flash`/`upgrade` |
| `CHIP` | `esp32` | |
| `BAUD` | `460800` | Flashing speed |
| `OFFSET` | `0x1000` | Use `0x0` for ESP32-S3, C3 or C6 |
| `SRC` | `src` | Folder uploaded by `make push` |
| `PULL_DIR` | `pulled` | Folder where `make pull` saves files |
