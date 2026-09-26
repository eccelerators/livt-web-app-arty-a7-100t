# Prefer an activated Vivado installation; allow VIVADO=/path/to/vivado.
VIVADO ?= $(shell command -v vivado 2>/dev/null || ls /tools/Xilinx/*/Vivado/bin/vivado 2>/dev/null | sort -V | tail -1)
JOBS ?= 4
export JOBS ARTY_TARGET ARTY_CFGMEM_PART ARTY_JTAG_KHZ WEBAPP_IP_REPO BOARD_REPO

ifeq ($(strip $(VIVADO)),)
VIVADO = vivado
endif

all: project

help:
	@printf '%s\n' \
	  'make project           Create or recreate the Vivado project' \
	  'make build             Build and check timing, then write the bitstream' \
	  'make create-flash      Build and generate flash images; no programming' \
	  'make flash             Build, program, verify and boot configuration flash' \
	  'make block-design      Export the current block design to scripts/' \
	  'make block-design-pdf  Export its PDF to work/ (GUI display required)' \
	  'make clean             Remove local build output; preserve prebuilt/'

prepare:
	mkdir -p work

flash: create-flash
	@"$(VIVADO)" -mode batch \
			-source scripts/flash_device.tcl \
			-notrace \
			-nojournal \
			-tempDir work \
			-log work/vivado_flash.log

create-flash: build
	@"$(VIVADO)" -mode batch \
			-source scripts/create_flash.tcl \
			-notrace \
			-nojournal \
			-tempDir work \
			-log work/vivado_create_flash.log

project: prepare
	@"$(VIVADO)" -mode batch -source scripts/create_project.tcl -notrace -nojournal -tempDir work -log work/vivado.log

build: prepare
	@"$(VIVADO)" -mode batch -source scripts/build_project_local.tcl -notrace -nojournal -tempDir work -log work/vivado_build.log

block-design-pdf:
	@"$(VIVADO)" -mode batch -source scripts/write_block_design_pdf.tcl -notrace -nojournal -tempDir work -log work/vivado.log

block-design:
	@"$(VIVADO)" -mode batch -source scripts/write_block_design.tcl -notrace -nojournal -tempDir work -log work/vivado.log

clean:
	@rm -rf .Xil vivado*.log vivado*.str vivado*.jou
	@rm -rf work

.PHONY: all help prepare project build clean block-design-pdf block-design flash create-flash
