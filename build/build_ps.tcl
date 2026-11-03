# Vitis 2020.2 XSCT: xsct build/build_ps.tcl <rx.xsa> [workspace]
set project_root [file normalize [file join [file dirname [info script]] ..]]
if {$argc < 1 || $argc > 2} {
    error {Usage: xsct build/build_ps.tcl <rx.xsa> [workspace]}
}
set hw_xsa [file normalize [lindex $argv 0]]
if {![file exists $hw_xsa]} {error "XSA not found: $hw_xsa"}
if {$argc == 2} {
    set workspace [file normalize [lindex $argv 1]]
} else {
    set workspace [file join $project_root build results vitis_rx]
}
if {[file exists [file join $workspace uwoc_rx]]} {
    error {Application already exists. Select a new workspace to keep the existing project.}
}
file mkdir $workspace
setws $workspace
platform create -name uwoc_rx_platform -hw $hw_xsa -proc ps7_cortexa9_0 -os standalone
domain active standalone_domain
bsp setlib -name lwip211 -ver 1.3
bsp config stdin ps7_uart_0
bsp config stdout ps7_uart_0
platform generate
app create -name uwoc_rx -platform uwoc_rx_platform -domain standalone_domain -template {Empty Application(C)}
importsources -name uwoc_rx -path [file join $project_root src ps rx]
app config -name uwoc_rx -add include-path [file join $workspace uwoc_rx src]
app build -name uwoc_rx
puts "Receiver ELF: [file join $workspace uwoc_rx Debug uwoc_rx.elf]"
