set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
set project_work  "work"
set project_name "WebAppFpga"
set project_part "xc7a100tcsg324-1"
set project_src  "src"
set project_scripts "scripts"
set project_constraints "constraints"
set board_design_filepath "${project_work}/${project_name}.srcs/sources_1/bd/${project_name}/${project_name}.bd"
set board_design_wrapper_filepath "${project_work}/${project_name}.gen/sources_1/bd/${project_name}/hdl/${project_name}_wrapper.vhd"

proc printMessage {outMsg} {
    puts " --------------------------------------------------------------------------------"
    puts " -- $outMsg"
    puts " --------------------------------------------------------------------------------"
}

printMessage "Project: ${project_name}   Part: ${project_part}   Source Folder: ${project_src}"

# Project-local Vivado workarounds for generated IP files.
source "${project_scripts}/preprocess_vivado_vhdl.tcl"

# Use the optional board-file checkout, or Vivado's installed board files.
set board_repo [file normalize "../../vivado-boards/new/board_files"]
if {[info exists ::env(BOARD_REPO)] && $::env(BOARD_REPO) ne ""} {
    set board_repo [file normalize $::env(BOARD_REPO)]
    if {![file isdirectory $board_repo]} { error "Board repository not found: $board_repo" }
}
if {[file isdirectory $board_repo]} {
    set_param board.repoPaths [concat [get_param board.repoPaths] [list $board_repo]]
}

set ip_repo [file normalize "../../livt/livt-web-app/package"]
if {[info exists ::env(WEBAPP_IP_REPO)] && $::env(WEBAPP_IP_REPO) ne ""} {
    set ip_repo [file normalize $::env(WEBAPP_IP_REPO)]
}
if {![file exists [file join $ip_repo component.xml]]} {
    error "Packaged WebApp IP not found at $ip_repo. Run scripts/package-ip.py in livt-web-app or set WEBAPP_IP_REPO."
}

file delete -force [file join $project_work project.ready]

# Create project
printMessage "Create the Vivado project"
create_project ${project_name} ${project_work} -part ${project_part} -force

# Set project properties
set obj [current_project]
set_property -name "board_part" -value "digilentinc.com:arty-a7-100:part0:1.1" -objects $obj
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "ip_cache_permissions" -value "read write" -objects $obj
set_property -name "ip_output_repo" -value "${project_work}/${project_name}.cache/ip" -objects $obj
set_property -name "part" -value ${project_part} -objects $obj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
set_property -name "simulator_language" -value "Mixed" -objects $obj
set_property -name "target_language" -value "VHDL" -objects $obj
set_property -name "xpm_libraries" -value "XPM_CDC XPM_FIFO XPM_MEMORY" -objects $obj
set_property -name "xsim.array_display_limit" -value "64" -objects $obj

# Need to enable VHDL 2008
set_param project.enableVHDL2008 1

#------------------------------------------------------------------------
printMessage "Set IP repository paths"

set obj [get_filesets sources_1]

set_property ip_repo_paths [list $ip_repo] $obj

# Rebuild user ip_repo's index before adding any source files
update_ip_catalog -rebuild

#------------------------------------------------------------------------
printMessage "Include VHDL files into project"

if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}
set obj [get_filesets sources_1]
set files_vhd [list [file normalize "${project_src}/WebAppFpgaTop.vhd"]]
add_files -norecurse -fileset $obj $files_vhd

foreach i $files_vhd {
    set file_obj [get_files -of_objects [get_filesets sources_1] [file tail [list $i]]]
    set_property -name "file_type" -value "VHDL 2008" -objects $file_obj
}

set obj [get_filesets sources_1]
set_property -name "top" -value "WebAppFpgaTop" -objects $obj
set_property -name "top_auto_set" -value "0" -objects $obj
set_property -name "top_file" -value "${project_src}/WebAppFpgaTop.vhd" -objects $obj

#------------------------------------------------------------------------
source "${project_scripts}/${project_name}.tcl"

generate_target all [get_files ${board_design_filepath}]
export_ip_user_files -of_objects [get_files ${board_design_filepath}] -no_script -sync -force -quiet
preprocessGeneratedVivadoVhdl ${project_name}

make_wrapper -files [get_files ${board_design_filepath}] -top
if {![file exists $board_design_wrapper_filepath]} {
  error "Block design wrapper was not generated at ${board_design_wrapper_filepath}"
}
add_files -norecurse -fileset $obj $board_design_wrapper_filepath
set wrapper_file_obj [get_files -of_objects [get_filesets sources_1] [file tail $board_design_wrapper_filepath]]
set_property -name "file_type" -value "VHDL 2008" -objects $wrapper_file_obj
update_compile_order -fileset sources_1

#------------------------------------------------------------------------
printMessage "Adding constraint files..."

if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]

set files_cons [list \
 "[file normalize "${project_constraints}/${project_name}.xdc"]"\
]

add_files -fileset constrs_1 $files_cons

foreach i $files_cons {
    set file_obj [get_files -of_objects [get_filesets constrs_1] [list $i]]
    set_property -name "file_type" -value "XDC" -objects $file_obj
    set_property -name "used_in_implementation" -value "1" -objects $file_obj
    set_property -name "used_in_synthesis" -value "1" -objects $file_obj
}

close_project -verbose

#------------------------------------------------------------------------
printMessage "Project: ${project_name}   Part: ${project_part}   Source Folder: ${project_src}"

set ready [open [file join $project_work project.ready] w]
puts $ready "Project creation completed"
close $ready
