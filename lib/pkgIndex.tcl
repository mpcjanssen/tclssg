# Tclssg, a static website generator.
# Copyright (C) 2013, 2014, 2015 Danyil Bohdan.
# This code is released under the terms of the MIT license. See the file
# LICENSE for details.

set maindir $dir
set dir [file join $maindir external] ; source [file join $dir pkgIndex.tcl]
set dir [file join $maindir tclssg] ; source [file join $dir pkgIndex.tcl]
unset maindir
