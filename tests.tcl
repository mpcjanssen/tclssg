#!/usr/bin/env tclsh
# Tclssg, a static website generator.
# Copyright (C) 2013, 2014, 2015 Danyil Bohdan.
# This code is released under the terms of the MIT license. See the file
# LICENSE for details.

package require fileutil
package require struct
package require tcltest

namespace eval ::tclssg::tests {
    variable path [file dirname [file dirname [file normalize $argv0/___]]]
    variable setup [list apply {{path} {
        lappend ::auto_path [file join $path lib]
        package require tclssg-lib
        namespace import ::tclssg::utils::*
        cd $path
        set result {}
        set correct {}
    }} $path]

    proc diff-available? {} {
        set testPath [::fileutil::tempfile]
        file delete $testPath
        file mkdir $testPath
        set error [catch {
            exec diff -r $testPath $testPath
        }]
        file delete -force $testPath
        return [expr { !$error }]
    }

    tcltest::testConstraint diffAvailable [diff-available?]

    tcltest::test test1 {incremental-clock-scan} \
                -setup $setup \
                -body {
        set result {}
        lappend result [incremental-clock-scan {2014-06-26 20:10}]
        lappend result [incremental-clock-scan {2014-06-26T20:10}]
        lappend result [incremental-clock-scan {2014 06 26 20 10}]
        lappend result [incremental-clock-scan {2014/06/26 20:10}]
        lappend result [incremental-clock-scan {2014/06/26 20:10}]

        lappend result [lindex [incremental-clock-scan {2014}] 0]
        lappend result [lindex [incremental-clock-scan {2014-01}] 0]
        lappend result [lindex [incremental-clock-scan {2014-01-01 00:00:00}] 0]

        return [lsort -unique $result]
    } -result [list \
        [clock scan {2014-01-01} -format {%Y-%m-%d}] \
        [list [clock scan {2014-06-26-20-10} -format {%Y-%m-%d-%H-%M}] \
            {%Y-%m-%dT%H:%M}] \
    ]

    tcltest::test test2 {slugify} \
                -setup $setup \
                -body {
        set result {}
        lappend result [slugify {Hello, World!}]
        lappend result [slugify {hello world}]

        return [lsort -unique $result]
    } -result hello-world

    tcltest::test test3 {replace-path-root} \
                -setup $setup \
                -body {
        set result {}
        lappend result [replace-path-root ./a/b/c/d/e/f ./a ./x]
        lappend result [replace-path-root ./a/b/c/d/e/f ./a/b/c ./x/b/c]
        lappend result [replace-path-root a/b/c/d/e/f a x]
        lappend result [replace-path-root a/b/./c/d/e/f a/b/c x/b/c]

        lappend result [replace-path-root /././././././././b / /a]

        return [lsort -unique $result]
    } -result [list /a/b x/b/c/d/e/f]

    tcltest::test test4 {dict-default-get} \
                -setup $setup \
                -body {
        set result {}
        lappend result [dict-default-get testValue {} someKey]
        lappend result [dict-default-get -1 {someKey testValue} someKey]
        lappend result [dict-default-get -1 {someKey {anotherKey testValue}} \
                         someKey anotherKey]

        return [lsort -unique $result]
    } -result testValue

    tcltest::test test5 {add-number-before-extension} \
                -setup $setup \
                -body {
        set result {}
        set correct {}
        lappend result [add-number-before-extension "filename.ext" 0]
        lappend correct filename.ext
        lappend result [add-number-before-extension "filename.ext" 0 "-%d" 1]
        lappend correct filename-0.ext

        for {set i 1} {$i < 11} {incr i} {
            lappend result [add-number-before-extension "filename.ext" $i]
            lappend correct filename-$i.ext

            lappend result [add-number-before-extension "filename.ext" \
                    $i "%03d"]
            lappend correct [format filename%03d.ext $i]

            lappend result [add-number-before-extension "filename.ext" \
                    $i "%03d" -1]
            lappend correct [format filename%03d.ext $i]
        }

        return [expr {$result eq $correct}]
    } -result 1

    tcltest::test test6 {get-page-settings} \
                -setup $setup \
                -body {
        set prased {}
        lappend prased [get-page-settings {{hello world} Hello, world!}]
        lappend prased [get-page-settings {{ hello world } Hello, world!}]
        lappend prased [get-page-settings {{hello world} Hello, world!}]
        lappend prased [get-page-settings {{hello world}

            Hello, world!}]
        lappend prased [get-page-settings {{
                hello world
            }

            Hello, world!}]

        set result {}
        set first [lindex $prased 0]
        foreach elem [lrange $prased 1 end] {
            lappend result [::struct::list equal $first $elem]
        }

        return [lsort -unique $result]
    } -result 1

    proc with-temporary-project {dirVarName script} {
        upvar 1 $dirVarName tempProjectDir

        set tempProjectDir [::fileutil::tempfile]
        # Remove the temporary file so that Tclssg can replace it with
        # a temporary project directory.
        file delete $tempProjectDir

        exec tclsh ssg.tcl init $tempProjectDir/input $tempProjectDir/output
        uplevel 1 $script

        file delete -force $tempProjectDir
    }

    tcltest::test test7 {Tclssg command line commands} \
                -setup $setup \
                -constraints diffAvailable \
                -body {
        with-temporary-project project {
            set tclssgArguments [list $project/input $project/output]

            exec tclsh ssg.tcl version
            exec tclsh ssg.tcl help

            # Set deployment options in the website config.
            set configFile $project/input/website.conf
            set config [::fileutil::cat $configFile]
            dict set config deployCopy path $project/deploy-copy-test
            dict set config deployCustom [list \
                start "cp -r \"\$outputDir\"\
                        $project/deploy-custom-test" \
                file {} \
                end {} \
            ]
            ::fileutil::writeFile $configFile $config

            exec tclsh ssg.tcl build {*}$tclssgArguments
            exec tclsh ssg.tcl update --templates --yes {*}$tclssgArguments
            exec tclsh ssg.tcl build {*}$tclssgArguments
            exec tclsh ssg.tcl deploy-copy {*}$tclssgArguments
            exec tclsh ssg.tcl deploy-custom {*}$tclssgArguments
            exec tclsh ssg.tcl clean {*}$tclssgArguments

            set result [exec diff -r \
                    $project/deploy-copy-test \
                    $project/deploy-custom-test]
        }
        return $result
    } -result {}

    tcltest::test test8 {Tclssg as a library} \
                -setup $setup \
                -body {
        with-temporary-project project {
            set file [file join $project libtest.tcl]
            fileutil::writeFile $file [
                subst {
                    source [file join $path ssg.tcl]
                    tclssg configure
                    tclssg command build $project/input $project/output
                    puts done
                }
            ]
            set result [exec [info nameofexecutable] $file]
        }
        return [lindex $result end]
    } -result done

    # Exit with a nonzero status if there are failed tests.
    if {$::tcltest::numTests(Failed) > 0} {
        exit 1
    }
}
