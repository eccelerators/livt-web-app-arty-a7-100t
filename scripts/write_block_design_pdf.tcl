set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
set project_work  "work"
set project_name "WebAppFpga"
set project_filepath "${project_work}/${project_name}.xpr"
set board_design_filepath "${project_work}/${project_name}.srcs/sources_1/bd/WebAppFpga/WebAppFpga.bd"
if {![file exists $project_filepath] || ![file exists $board_design_filepath]} {
    error "Vivado project/block design missing. Run make project first."
}
open_project "${project_filepath}"
start_gui
open_bd_design "${board_design_filepath}"
write_bd_layout -format pdf -orientation landscape work/WebAppFpga.pdf -force
stop_gui
close_project
