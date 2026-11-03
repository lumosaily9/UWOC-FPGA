# Vivado 2020.2: vivado -mode gui -source build/open_project.tcl -tclargs tx|rx
set uwoc_root [file normalize [file join [file dirname [info script]] ..]]
if {![info exists argv] || [llength $argv] != 1 || [lindex $argv 0] ni {tx rx}} {
    error {Usage: vivado -mode gui -source build/open_project.tcl -tclargs tx|rx}
}
set uwoc_role [lindex $argv 0]
if {$uwoc_role eq "tx"} {
    set uwoc_project_dir [file join $uwoc_root src pl tx]
    set uwoc_project [file join $uwoc_project_dir uwoc_tx.xpr]
    set uwoc_bd [file join $uwoc_project_dir uwoc_tx.srcs sources_1 bd design_1 design_1.bd]
    set uwoc_serial_cell fifo2uart_v2_0
} else {
    set uwoc_project_dir [file join $uwoc_root src pl rx]
    set uwoc_project [file join $uwoc_project_dir uwoc_rx.xpr]
    set uwoc_bd [file join $uwoc_project_dir uwoc_rx.srcs sources_1 bd camera_rx camera_rx.bd]
    set uwoc_serial_cell uart2fifo_v2_0
}
open_project $uwoc_project
source [file join $uwoc_root build refresh_ip.tcl]
uwoc_refresh_ip [file join $uwoc_root src ip_repo]
set_property ip_repo_paths [list [file join $uwoc_root src ip_repo]] [current_project]
update_ip_catalog -rebuild
open_bd_design $uwoc_bd
set_property -dict [list CONFIG.CLK_FREQ {200000000} CONFIG.BAUD_RATE {20000000}] [get_bd_cells $uwoc_serial_cell]
set_property CONFIG.Coe_File [file join $uwoc_root data $uwoc_role dds_239x8b_wave.coe] [get_bd_cells blk_mem_gen_0]
save_bd_design
update_compile_order -fileset sources_1
puts "Opened $uwoc_role: xc7z010clg400-1, 200 MHz logic, 20 Mbit/s OOK."
