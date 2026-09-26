proc preprocessLivtLangPackageFile {file_path} {
    if {![file exists $file_path]} {
        puts "WARNING: Cannot preprocess missing file: $file_path"
        return 0
    }

    set in_unsupported_to_string 0
    set changed 0
    set in_file [open $file_path r]
    set content [read $in_file]
    close $in_file

    set output_lines {}
    foreach line [split $content "\n"] {
        set patched_line $line

        if {[regexp {^\s*-- vivado-preprocess:} $line]} {
            lappend output_lines $line
            continue
        }

        if {[regexp {^\s*function to_string\(value: (integer_vector|boolean_vector)\) return string is\s*$} $line]} {
            set in_unsupported_to_string 1
        }

        if {$in_unsupported_to_string ||
            [regexp {^\s*function to_string\(value: (integer_vector|boolean_vector)\) return string;\s*$} $line]} {
            set patched_line "-- vivado-preprocess: $line"
            set changed 1
        }

        lappend output_lines $patched_line

        if {$in_unsupported_to_string && [regexp {^\s*end function;\s*$} $line]} {
            set in_unsupported_to_string 0
        }
    }

    if {$changed} {
        set out_file [open $file_path w]
        puts -nonewline $out_file [join $output_lines "\n"]
        close $out_file
        puts "Preprocessed VHDL-2008-only vector overloads in $file_path"
        return 1
    }

    return 0
}

# Current Vivado compatibility adjustment only. Legacy EthernetFrameIo and
# wrapper rewrites are intentionally excluded from the current component graph.
proc preprocessGeneratedVivadoVhdl {{bd_name WebAppFpga}} {
    set project_dir [get_property DIRECTORY [current_project]]
    set project_name [get_property NAME [current_project]]
    set pattern [file join $project_dir "${project_name}.gen" sources_1 bd $bd_name ipshared * * Livt.Lang.Package.vhd]
    set patched 0
    foreach file_path [glob -nocomplain $pattern] {
        incr patched [preprocessLivtLangPackageFile $file_path]
    }
    puts "Preprocessed $patched generated Livt.Lang.Package.vhd file(s)."
}
