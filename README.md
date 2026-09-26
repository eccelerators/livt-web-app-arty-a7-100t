# FPGA Web App on the Arty A7-100T

A small HTTP application running directly in FPGA logic, with no soft CPU or
operating system. The design serves Home, About and Status pages at
**http://10.0.0.2/** using [Livt.Web](https://github.com/eccelerators/livt-web)
and [Livt.Net](https://github.com/eccelerators/livt-net).

This repository contains the board integration for the **Digilent Arty A7-100T**
(`xc7a100tcsg324-1`): EthernetLite, clocks, reset, UART and activity LEDs. Application
sources and routes live in [livt-web-app](https://github.com/eccelerators/livt-web-app).

![The FPGA web application's home page](docs/resources/browser-home-page.png)

## Try the pre-built demo

Download the [bitstream](prebuilt/WebAppFpgaTop.bit) for volatile JTAG loading or
the [flash image](prebuilt/WebAppFpga.mcs) for booting from configuration memory.
Follow the [programming instructions](prebuilt/README.md); checksums and the
verified image's provenance are included there.

You need the Arty A7-100T, USB JTAG and Vivado Hardware Manager. **Livt and a Livt
licence are not needed to program these existing images.**

After programming, connect Ethernet and give the host a compatible unused address
such as `10.0.0.101/24`. Open **http://10.0.0.2/**. The `/status` page displays
application counters. HTML is embedded in the FPGA; Bootstrap CSS and the logo
are loaded by the browser from external websites.

The demo supports three GET routes, a single peer, requests in one TCP segment
and responses within a 1460-byte HTTP budget. It has no TCP retransmission,
reassembly or TLS. SPI flash currently stores the FPGA configuration; separate
web-asset storage is planned.

## Build from source

Source builds use the Linux console workflow and require:

- Livt with a valid licence permitting package downloads and compilation.
  A trial is available through [Eccelerators](https://eccelerators.com/Identity/Account/Register).
- Git, GNU Make, Python 3 and GHDL for fetching sources and packaging/checking the IP.
- AMD Vivado; the console build and pre-built image were verified with **2026.1**.
- [Digilent board files](https://github.com/Digilent/vivado-boards), including
  `digilentinc.com:arty-a7-100:part0:1.1`.

### Workspace layout

From an empty workspace:

```sh
mkdir -p livt eccelerators
git clone https://github.com/eccelerators/livt-web-app.git livt/livt-web-app
git clone https://github.com/eccelerators/livt-web-app-arty-a7-100t.git eccelerators/livt-web-app-arty-a7-100t
git clone https://github.com/Digilent/vivado-boards.git
```

The default build finds the application IP at `../../livt/livt-web-app/package`
and board files at `../../vivado-boards/new/board_files`. An existing Vivado board
installation also works. For another layout, set `WEBAPP_IP_REPO` and `BOARD_REPO`
to the respective directories when creating or rebuilding the project.

### Package the application

In `livt/livt-web-app`:

```sh
livt sync
python3 scripts/package-ip.py
```

The manifest resolves published development packages. The packaging script
requires Vivado and GHDL on PATH, or `LIVT_VIVADO_PATH` and `LIVT_GHDL_PATH` set
to their executables. It produces `package/component.xml` with IP identity
`eccelerators.com:samples:webapp:1.0`.

### Build and flash

In `eccelerators/livt-web-app-arty-a7-100t`:

```sh
make build
make flash
```

`make build` creates the project, runs synthesis and implementation, checks
routed setup/hold timing and writes `work/WebAppFpga.runs/impl_1/WebAppFpgaTop.bit`.
Reports are in `work/{timing_summary,utilization,drc,cdc}.rpt`.

`make create-flash` builds if needed and generates the `.mcs` and `.bin` files
without programming a board.

`make flash` builds if needed, generates `work/WebAppFpga.mcs` and `.bin`, then
erases, programs, verifies and boots the connected board's configuration flash.
For the downloadable images, use Hardware Manager as described above instead.

After changing packaged IP, board scripts or repository paths, run `make clean`
before `make build`. This removes local build output but preserves `prebuilt/`.
The board build does not regenerate the Livt application IP.

| Setting | Purpose |
|---|---|
| `VIVADO=/path/to/vivado` | Override the executable found on PATH or under `/tools/Xilinx`. |
| `JOBS=4` | Set implementation parallelism; defaults to four. |
| `WEBAPP_IP_REPO=/path/to/package` | Select the packaged application IP. |
| `BOARD_REPO=/path/to/board_files` | Select the Digilent board-file directory. |
| `ARTY_TARGET=...` | Select a JTAG target when several are attached. |
| `ARTY_CFGMEM_PART=...` | Override the default `s25fl128sxxxxxx0-spi-x1_x2_x4` flash part. |
| `ARTY_JTAG_KHZ=6000` | Set JTAG speed; defaults to 6 MHz. |

## Repository contents

| Path | Contents |
|---|---|
| `src/`, `constraints/` | Top-level VHDL and board pin/timing constraints. |
| `scripts/`, `Makefile` | Reproducible Vivado project, build and flash flow. |
| `prebuilt/` | Verified deployment images, checksums and programming guide. |
| `docs/` | [Article](docs/BLOG.md), diagrams and screenshots. |

`make help` lists the available targets. `make project` creates (or recreates)
the project without building a bitstream. Maintainers can
use `make block-design` to save the current block design back to its Tcl source,
and `make block-design-pdf` to export a PDF under `work/` (requires a GUI display).

The build keeps the Vivado vector-overload compatibility adjustment used by the
verified image, as well as its area optimization settings. Protocol and
application tests live in the Livt package/application repositories. Hardware
verification of the pre-built files is documented in [prebuilt/README.md](prebuilt/README.md).

For board details, see the [Arty A7 reference manual](https://digilent.com/reference/programmable-logic/arty-a7/reference-manual).
