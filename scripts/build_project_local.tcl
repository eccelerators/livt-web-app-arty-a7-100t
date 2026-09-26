# Recreate a cleaned project, then build through the bitstream from the console.
set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
set project_file [file join $root work WebAppFpga.xpr]
if {![file exists $project_file] || ![file exists [file join $root work project.ready]]} {
    source [file join $root scripts create_project.tcl]
}
open_project $project_file
# The composed HTTP graph needs area optimization to fit the A7-100T.
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE ExploreArea [get_runs impl_1]
set_property STEPS.OPT_DESIGN.TCL.POST [file join $root scripts board_area_optimization.tcl] [get_runs impl_1]
# Clear the removed, empty legacy hook when opening an existing project.
reset_property STEPS.OPT_DESIGN.TCL.PRE [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set jobs 4
if {[info exists ::env(JOBS)]} { set jobs $::env(JOBS) }
if {![string is integer -strict $jobs] || $jobs < 1} { error "JOBS must be a positive integer" }
set_param general.maxThreads $jobs
update_compile_order -fileset sources_1
proc wait_for_complete {name} {
    wait_on_run $name
    set run [get_runs $name]
    if {[get_property PROGRESS $run] ne "100%" ||
        [string match -nocase *error* [get_property STATUS $run]]} {
        error "Run $name failed: [get_property STATUS $run]. See work/WebAppFpga.runs/$name/runme.log"
    }
}
if {[get_property PROGRESS [get_runs synth_1]] ne "100%" || [get_property NEEDS_REFRESH [get_runs synth_1]]} {
    reset_run synth_1
    launch_runs synth_1 -jobs $jobs
    wait_for_complete synth_1
}
set bitstream [file join $root work WebAppFpga.runs impl_1 WebAppFpgaTop.bit]
set routed [file join $root work WebAppFpga.runs impl_1 WebAppFpgaTop_routed.dcp]
if {![file exists $routed] || [get_property NEEDS_REFRESH [get_runs impl_1]] ||
    [get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    reset_run impl_1
    launch_runs impl_1 -to_step {phys_opt_design (Post-Route)} -jobs $jobs
    wait_for_complete impl_1
}
# Resume a previously routed run without repeating successful synthesis/placement.
set postroute [file join $root work WebAppFpga.runs impl_1 WebAppFpgaTop_postroute_physopt.dcp]
if {![file exists $postroute] && ![file exists $bitstream]} {
    launch_runs impl_1 -to_step {phys_opt_design (Post-Route)} -jobs $jobs
    wait_for_complete impl_1
}
open_run impl_1
report_timing_summary -file [file join $root work timing_summary.rpt]
report_utilization -file [file join $root work utilization.rpt]
report_drc -file [file join $root work drc.rpt]
report_cdc -file [file join $root work cdc.rpt]
foreach kind {max min} {
    set path [get_timing_paths -quiet -delay_type $kind -max_paths 1]
    if {[llength $path] == 0 || [get_property SLACK $path] < 0} {
        error "Routed $kind timing failed. See work/timing_summary.rpt; do not flash this build."
    }
}
close_design
if {![file exists $bitstream]} {
    launch_runs impl_1 -to_step write_bitstream -jobs $jobs
    wait_for_complete impl_1
}
if {![file exists $bitstream]} { error "Implementation did not produce $bitstream" }
puts "Bitstream ready: $bitstream"
close_project
