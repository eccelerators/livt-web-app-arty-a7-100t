set origin_dir [file normalize "."]
set project_name "WebAppFpga"
set top_name "WebAppFpgaTop"
set cfgmem_part "s25fl128sxxxxxx0-spi-x1_x2_x4"
if {[info exists ::env(ARTY_CFGMEM_PART)] && $::env(ARTY_CFGMEM_PART) ne ""} {
    set cfgmem_part $::env(ARTY_CFGMEM_PART)
}

set project_filepath [file join $origin_dir work "${project_name}.xpr"]
set bitstream_filepath [file join $origin_dir work "${project_name}.runs" impl_1 "${top_name}.bit"]
set mcs_filepath [file join $origin_dir work "${project_name}.mcs"]

if {![file exists $project_filepath]} {
    error "Vivado project not found at $project_filepath. Run make project first."
}

if {![file exists $bitstream_filepath]} {
    error "Bitstream not found at $bitstream_filepath. Run implementation/bitstream generation before make flash."
}

if {![file exists $mcs_filepath]} {
    error "Flash image not found at $mcs_filepath. Run make create-flash first."
}

open_project $project_filepath

# Use the verified 6 MHz JTAG programming speed.
set jtag_khz 6000
if {[info exists ::env(ARTY_JTAG_KHZ)] && $::env(ARTY_JTAG_KHZ) ne ""} {
    set jtag_khz $::env(ARTY_JTAG_KHZ)
}
if {![string is integer -strict $jtag_khz] || $jtag_khz <= 0} {
    error "ARTY_JTAG_KHZ must be a positive integer"
}
open_hw_manager
connect_hw_server

set targets [get_hw_targets]
if {[info exists ::env(ARTY_TARGET)] && $::env(ARTY_TARGET) ne ""} {
    set targets [get_hw_targets $::env(ARTY_TARGET)]
}
if {[llength $targets] != 1} {
    error "Expected one JTAG target; found $targets. Select the Arty with ARTY_TARGET."
}
set target [lindex $targets 0]
set_property PARAM.FREQUENCY [expr {$jtag_khz * 1000}] $target
open_hw_target $target
puts "JTAG frequency: [get_property PARAM.FREQUENCY $target] Hz"
set devices [get_hw_devices "xc7a100t*"]
if {[llength $devices] != 1} {
    error "Expected exactly one xc7a100t on the selected target; found $devices."
}

set hw_device [lindex $devices 0]
current_hw_device $hw_device
refresh_hw_device -update_hw_probes false $hw_device

set cfgmem_parts [get_cfgmem_parts $cfgmem_part]
if {[llength $cfgmem_parts] == 0} {
    error "Configuration memory part '$cfgmem_part' is not available in this Vivado installation."
}

create_hw_cfgmem -hw_device $hw_device [lindex $cfgmem_parts 0]
set hw_cfgmem [get_property PROGRAM.HW_CFGMEM $hw_device]

set_property PROGRAM.ADDRESS_RANGE {use_file} $hw_cfgmem
set_property PROGRAM.FILES [list $mcs_filepath] $hw_cfgmem
set_property PROGRAM.PRM_FILE {} $hw_cfgmem
set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} $hw_cfgmem
set_property PROGRAM.BLANK_CHECK 0 $hw_cfgmem
set_property PROGRAM.ERASE 1 $hw_cfgmem
set_property PROGRAM.CFG_PROGRAM 1 $hw_cfgmem
set_property PROGRAM.VERIFY 1 $hw_cfgmem
set_property PROGRAM.CHECKSUM 0 $hw_cfgmem

puts "Programming configuration flash:"
puts "  Device: $hw_device"
puts "  Flash:  $cfgmem_part"
puts "  Image:  $mcs_filepath"

# The flash-programming helper belongs to the selected FPGA device.
# Load the SPI programming helper, not the application bitstream, before cfgmem.
set helper [get_property PROGRAM.HW_CFGMEM_BITFILE $hw_device]
create_hw_bitstream -hw_device $hw_device $helper
set_property PROGRAM.FILE $helper $hw_device
program_hw_devices $hw_device
refresh_hw_device -update_hw_probes false $hw_device
program_hw_cfgmem -hw_cfgmem $hw_cfgmem

boot_hw_device $hw_device

close_hw_target
disconnect_hw_server
close_hw_manager
close_project

puts "Flash programming complete."
