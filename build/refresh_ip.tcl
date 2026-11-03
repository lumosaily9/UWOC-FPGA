# Recalculate IP-XACT checksums with Vivado's own IP Packager.
# Called by open_project.tcl before the local catalog is rebuilt.
proc uwoc_refresh_ip {repo_dir} {
    set components [lsort [glob -nocomplain -directory $repo_dir */component.xml]]
    if {[llength $components] == 0} {
        error "No component.xml files found in $repo_dir"
    }
    foreach component $components {
        ipx::open_core [file normalize $component]
        set core [ipx::current_core]
        set failed [catch {
            ipx::update_checksums $core
            ipx::save_core $core
        } message options]
        ipx::unload_core $core
        if {$failed} {
            return -options $options $message
        }
        puts "Refreshed IP checksums: [file tail [file dirname $component]]"
    }
    return [llength $components]
}
