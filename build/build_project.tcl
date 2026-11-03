# Vivado 2020.2 batch build; run from any directory.
# vivado -mode batch -source build/build_project.tcl -tclargs tx validate
# Stages: validate, synth, impl, bitstream. The default stage is bitstream.
set uwoc_build_args $argv
if {[llength $uwoc_build_args] < 1 || [llength $uwoc_build_args] > 3} {
    error {Usage: build_project.tcl tx|rx ?validate|synth|impl|bitstream? ?jobs?}
}
set uwoc_stage [expr {[llength $uwoc_build_args] > 1 ? [lindex $uwoc_build_args 1] : "bitstream"}]
set uwoc_jobs [expr {[llength $uwoc_build_args] > 2 ? [lindex $uwoc_build_args 2] : 4}]
if {$uwoc_stage ni {validate synth impl bitstream}} {error "Unknown build stage: $uwoc_stage"}
if {![string is integer -strict $uwoc_jobs] || $uwoc_jobs < 1} {error "jobs must be a positive integer"}
set argv [list [lindex $uwoc_build_args 0]]
source [file join [file dirname [info script]] open_project.tcl]
set uwoc_result [file join $uwoc_root build results $uwoc_role]
file mkdir $uwoc_result
report_ip_status -file [file join $uwoc_result ip_status.rpt] -force
validate_bd_design
save_bd_design
if {$uwoc_stage eq "validate"} {
    puts "Block Design validation finished. Reports: $uwoc_result"
    close_project
    exit 0
}
generate_target all [get_files $uwoc_bd]
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs $uwoc_jobs
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "Synthesis did not complete: [get_property STATUS [get_runs synth_1]]"
}
open_run synth_1
report_utilization -file [file join $uwoc_result utilization_synth.rpt] -force
report_timing_summary -file [file join $uwoc_result timing_synth.rpt] -force
if {$uwoc_stage eq "synth"} {
    close_project
    exit 0
}
close_design
if {$uwoc_stage eq "bitstream"} {
    launch_runs impl_1 -to_step write_bitstream -jobs $uwoc_jobs
} else {
    launch_runs impl_1 -to_step route_design -jobs $uwoc_jobs
}
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "Implementation did not complete: [get_property STATUS [get_runs impl_1]]"
}
open_run impl_1
report_utilization -file [file join $uwoc_result utilization_impl.rpt] -force
report_timing_summary -file [file join $uwoc_result timing_impl.rpt] -force
report_drc -file [file join $uwoc_result drc.rpt] -force
if {$uwoc_stage eq "bitstream"} {
    set uwoc_bits [glob -nocomplain -directory [get_property DIRECTORY [get_runs impl_1]] *.bit]
    if {[llength $uwoc_bits] == 0} {error "Implementation produced no bitstream"}
    file copy -force [lindex $uwoc_bits 0] [file join $uwoc_result ${uwoc_role}_20mbps.bit]
    write_hw_platform -fixed -include_bit -force -file [file join $uwoc_result ${uwoc_role}_20mbps.xsa]
}
puts "Completed $uwoc_role stage $uwoc_stage. Reports: $uwoc_result"
close_project
exit 0
