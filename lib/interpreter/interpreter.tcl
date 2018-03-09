# Tclssg, a static website generator.
# Copyright (C) 2013, 2014, 2015, 2016, 2017, 2018 dbohdan.
# This code is released under the terms of the MIT license. See the file
# LICENSE for details.

namespace eval ::tclssg::interpreter {
    namespace export *
    namespace ensemble create
    namespace path ::tclssg

    proc create interp {
        ::safe::interpCreate $interp

        foreach {command alias} {
            ::base64::encode                    ::base64::encode
            ::base64::decode                    ::base64::decode
            ::csv::iscomplete                   ::csv::iscomplete
            ::csv::split                        ::csv::split
            ::json::json2dict                   ::json::json2dict
            ::Markdown::convert                 ::Markdown::convert

            ::msgcat::mclocale                  mclocale
            ::msgcat::mc                        mc
            ::msgcat::mcset                     mcset
            ::puts                              puts
            ::tclssg::db                        db
            ::tclssg::utils::dict-default-get   dict-default-get
            ::tclssg::utils::replace-path-root  replace-path-root
            ::tclssg::utils::slugify            slugify
            ::tclssg::utils::sha256             sha256
            ::tclssg::version                   version
            ::textutil::indent                  indent
        } {
            interp alias $interp $alias {} $command
        }

        set sourced {}
        foreach path $::tclssg::templates::paths {
            if {[file isdir $path]} {
                set files [lsort [glob -nocomplain -dir $path *.tcl]]
            } else {
                set files [list $path]
            }
            foreach file $files {
                if {$file in $sourced} continue
                lappend sourced $file
                interp eval $interp [utils::read-file -translation binary\
                                                      $file]
            }
        }

        return $interp
    }

    # Set variable $key to $value in the template interpreter $interp for each
    # key-value pair in a dictionary.
    proc inject {interp dictionary} {
        dict for {key value} $dictionary {
            interp eval $interp [list set $key $value]
        }
    }

} ;# namespace interpreter

package provide tclssg::interpreter 0