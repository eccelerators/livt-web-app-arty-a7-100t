# Pre-built Arty A7-100T web application

These files contain the web demo built with Vivado 2026.1 on 2026-09-25 and
verified on the Arty A7-100T. No Livt installation or Livt licence is needed to
program these existing images. Use Vivado Hardware Manager and the board's USB
JTAG connection; synthesis and a Livt package download are unnecessary.

Target: Digilent Arty A7-100T, FPGA `xc7a100tcsg324-1`.
Use GitHub's **Download raw file** action for the images below, or clone the
repository; saving the GitHub file-view page does not download the image.

| File | Purpose |
|---|---|
| [WebAppFpgaTop.bit](WebAppFpgaTop.bit) | Load the application directly into the FPGA through JTAG; volatile until power-off or reconfiguration. |
| [WebAppFpga.mcs](WebAppFpga.mcs) | Program configuration flash so the application can boot after power-on. |
| [SHA256SUMS](SHA256SUMS) | SHA-256 checksums of both files. |

The MCS contains the FPGA configuration at offset zero for a 16 MiB SPI flash,
using SPIx1. It includes the embedded HTML, not a separate web-asset filesystem.

## Load the bitstream

1. Connect and power the Arty A7-100T through its USB JTAG port.
2. Open Vivado Hardware Manager, connect to the hardware server and open the
   board target. Select the `xc7a100t` device.
3. Choose **Program Device**, select `WebAppFpgaTop.bit` and program it.
   No probes file is required.

## Program configuration flash

1. In Hardware Manager, select the FPGA and add its configuration memory device.
   The verified board uses `s25fl128sxxxxxx0-spi-x1_x2_x4`; select the part matching
   your board if its flash differs.
2. Select `WebAppFpga.mcs` as the configuration file. Use the file's address range
   and enable erase, program and verify. Programming replaces the existing
   configuration in that range.
3. Allow Vivado to load its flash-programming helper when prompted.
4. After successful verification, boot from configuration memory or power-cycle
   the board with its configuration mode set for SPI flash.

The repository's `make flash` target belongs to the source-build flow and may
rebuild the design. Use Hardware Manager for these pre-built files.

## Open the application

Connect the board's Ethernet port to the host or local network. Give the host a
compatible, unused address such as `10.0.0.101/24`, then open
[http://10.0.0.2/](http://10.0.0.2/). The application serves `/`, `/about` and
`/status` on TCP port 80. HTML comes from the FPGA; the browser currently loads
Bootstrap CSS and the logo from external websites.

## Verification and provenance

This image passed flash program/verify, boot and eight complete HTTP response
checks, including all three pages and error routes. Its final 100 MHz routed
setup/hold slack was +1.252/+0.011 ns. It uses 36,643 LUTs, 56,247 registers,
15,209 slices and 16 BRAM tiles.

These are the existing verified deployment artifacts, not a rebuild of the latest
checkout. They predate the source-only `WebApp` to `ArtyWebApp` rename and the
`FRAME_LENGTH` constant. The deployment used sibling Net/Web sources before the
app switched to registry dependencies. No source-commit identity is claimed.

Verify the files from this directory with:

```sh
sha256sum -c SHA256SUMS
```
