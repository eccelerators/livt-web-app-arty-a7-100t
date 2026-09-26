set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
set project_scripts "scripts"
set project_work  "work"
set project_name "WebAppFpga"
set project_filepath "${project_work}/${project_name}.xpr"
set board_design_filepath "${project_work}/${project_name}.srcs/sources_1/bd/${project_name}/${project_name}.bd"
if {![file exists $project_filepath] || ![file exists $board_design_filepath]} {
    error "Vivado project/block design missing. Run make project first."
}
open_project "${project_filepath}"
open_bd_design ${board_design_filepath}
validate_bd_design -force
write_bd_tcl ${project_scripts}/${project_name}.tcl -force
close_project -verbose
