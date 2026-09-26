set origin_dir [file normalize "."]
set project_name "WebAppFpga"
set top_name "WebAppFpgaTop"
set project_filepath [file join $origin_dir work "${project_name}.xpr"]
set bitstream_filepath [file join $origin_dir work "${project_name}.runs" impl_1 "${top_name}.bit"]
set mcs_filepath [file join $origin_dir work "${project_name}.mcs"]
set bin_filepath [file join $origin_dir work "${project_name}.bin"]

if {![file exists $project_filepath]} {
    error "Vivado project not found at $project_filepath. Run make project first."
}

if {![file exists $bitstream_filepath]} {
    error "Bitstream not found at $bitstream_filepath. Run implementation/bitstream generation before make create-flash."
}

open_project $project_filepath

# Arty A7 uses a 16 MiB SPI configuration flash. The Livt web application has
# no software image, so the configuration memory image contains only the FPGA
# bitstream at flash offset 0.
#
# Keep SPIx1 here unless the bitstream is generated with
# BITSTREAM.CONFIG.SPI_BUSWIDTH=4. Vivado rejects SPIx4 cfgmem generation for
# bitstreams whose SPI_BUSWIDTH property is still 1.
write_cfgmem -format mcs -interface SPIx1 -size 16 -loadbit "up 0x0 $bitstream_filepath" -file $mcs_filepath -force
write_cfgmem -format bin -interface SPIx1 -size 16 -loadbit "up 0x0 $bitstream_filepath" -file $bin_filepath -force

puts "Created flash images:"
puts "  $mcs_filepath"
puts "  $bin_filepath"

close_project
