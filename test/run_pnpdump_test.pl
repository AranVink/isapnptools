#!/usr/bin/perl
#
# run_pnpdump_test.pl
#
# $Header: /home/omer/work/cvs_repository/capital/isapnptools/test/run_pnpdump_test.pl,v 1.4 1999/11/07 12:20:41 omer Exp $
#
# Perl script for testing pnpdump by running a reference version
# and a version to be tested, and comparing their results.
#
# Copyright (C) 1999 by Omer Zak
# Licensed for general use under the GPL (version 2 or later).
#
#
# Usage:
# run_pnpdump_test.pl -r /sbin/pnpdump [-e] [-o] [-s] < test_case.txt
#
# where the file read via stdin consists of:
# One line - arguments to the pnpdump-1.19/pnpdump program.
# The rest of the file (if any) - copied verbatim to /etc/isapnp.gone.
#
# The meaning of the command line options is:
# -r  (requires an argument) path to the pnpdump version against
#     which we are comparing the version being tested.
#     This is required argument.
# -e  Display the stderr output of the reference pnpdump version.
# -o  Display the stdout output of the reference pnpdump version.
# -s  Display the script output of the reference pnpdump version
#     (if one was created).
#
######### Parameters ################################################
$opt_r = "";
    # Required argument.
$test_pnpdump = "../pnpdump";
    # We assume that the tests are run from subdirectory test of the
    # directory in which the new pnpdump has been built.
$stdoutname = "/tmp/pnpdump_stdout";
$stderrname = "/tmp/pnpdump_stderr";
$scriptname = "/tmp/pnpdump_script";

############## Default command line option settings #################
$opt_e = 0;
$opt_o = 0;

use Getopt::Std;
getopts('r:eos');

if ($opt_r =~ /^$/) {
    die "The required argument -r <reference pnpdump version> was not specified!\n";
}

unless ((-e $opt_r) && (-x $opt_r)) {
    die "The reference version $opt_r does not exist or is not executable!\n";
}

$| = 1;       # Always auto-flush stdout.
######## Ensure that we'll not overwrite important files ############
if (-e "/etc/isapnp.gone") {
    die "The regular /etc/isapnp.gone file was not saved!\n";
}
if (-e "${stdoutname}_ref") {
    die "The /tmp directory was not cleared from files used by run_pnpdump_test.pl!\n";
}
if (-e "${stderrname}_ref") {
    die "The /tmp directory was not cleared from files used by run_pnpdump_test.pl!\n";
}
if (-e "${scriptname}_ref") {
    die "The /tmp directory was not cleared from files used by run_pnpdump_test.pl!\n";
}
if (-e "${stdoutname}_test") {
    die "The /tmp directory was not cleared from files used by run_pnpdump_test.pl!\n";
}
if (-e "${stderrname}_test") {
    die "The /tmp directory was not cleared from files used by run_pnpdump_test.pl!\n";
}
if (-e "${scriptname}_test") {
    die "The /tmp directory was not cleared from files used by run_pnpdump_test.pl!\n";
}

########### Create the test case environment ########################

$cmdline_args = <STDIN>;
chop $cmdline_args;
$cmdline_args_ref = $cmdline_args;
$cmdline_args_test = $cmdline_args;

$test_also_scriptfile = 0;
if ($cmdline_args =~ /\%\%SCRIPTNAME\%\%/) {
    # The arguments specify that a script file is to be created.
    $cmdline_args_ref =~ s/\%\%SCRIPTNAME\%\%/${scriptname}_ref/;
    $cmdline_args_test =~ s/\%\%SCRIPTNAME\%\%/${scriptname}_test/;
    $test_also_scriptfile = 1;
} else {
    print "Script file is not to be generated in this test.\n";
}

$openit_flag = 1;
while (<STDIN>) {
    $line = $_;
    if (0 != $openit_flag) {
	die "Could not open temporary /etc/isapnp.gone for writing!" unless open GONE,">/etc/isapnp.gone";
	$openit_flag = 0;
    }
    print GONE $line;
}

if (0 == $openit_flag) {
    die "Could not close temporary /etc/isapnp.gone!" unless close GONE;
}

########### Actually run the test ###################################
print "Test >>" . $cmdline_args . "<<\n";

`$opt_r $cmdline_args_ref > ${stdoutname}_ref 2> ${stderrname}_ref`;
if (0 != $?) {
    print "Reference pnpdump-1.19 aborted!\n";
}

`$test_pnpdump $cmdline_args_test > ${stdoutname}_test 2> ${stderrname}_test`;
if (0 != $?) {
    print "Test pnpdump aborted!\n";
}

########### Compare results #########################################

{
    $st1 = system("diff --ignore-matching-lines='^#\\ .Id: pnpdump.c,v' --ignore-matching-lines='^#\\ Release isapnptools-' ${stdoutname}_ref ${stdoutname}_test");
    $st2 = system("diff ${stderrname}_ref ${stderrname}_test");
    $st3 = 0;

    if (0 !=  $test_also_scriptfile) {
        die "$opt_r failed to create the script ${scriptname}_ref!\n" unless (-e "${scriptname}_ref");
        die "$test_pnpdump failed to create the script ${scriptname}_test!\n" unless (-e "${scriptname}_test");
        $st3 = system("diff ${scriptname}_ref ${scriptname}_test");
    }
    if ((0 == $st1) && (0 == $st2) && (0 == $st3)) {
        print " . . . PASSED\n";
    } else {
        print "***** FAILED *****\n";
    }
}

########## Display selected results to the user, if so requested ####
if (0 != $opt_e) {
    print "\n**************************************************\n"
	.   "**                    stderr                    **\n"
	.   "**************************************************\n";
    system("cat ${stderrname}_ref");
}
if (0 != $opt_o) {
    print "\n**************************************************\n"
	.   "**                    stdout                    **\n"
	.   "**************************************************\n";
    system("cat ${stdoutname}_ref");
}
if (0 != $opt_s) {
    if (0 !=  $test_also_scriptfile) {
        print "\n**************************************************\n"
	    .   "**                    script                    **\n"
	    .   "**************************************************\n";
        system("cat ${scriptname}_ref");
    }
}
########## Erase temporary files ####################################
$unlinked_files = unlink ("${stdoutname}_ref", "${stderrname}_ref", "${scriptname}_ref");
die "Could not erase all output reference temporary files!\n" unless ((0 != $test_also_scriptfile ? 3 : 2) == $unlinked_files);
$unlinked_files = unlink ("${stdoutname}_test", "${stderrname}_test", "${scriptname}_test");
die "Could not erase all output test temporary files!\n" unless ((0 != $test_also_scriptfile ? 3 : 2) == $unlinked_files);

if (0 == $openit_flag) {
    # /etc/isapnp.gone was created, so we have to erase it.
    die "Could not erase temporary /etc/isapnp.gone" unless unlink "/etc/isapnp.gone";
}
#####################################################################
# End of run_pnpdump_test.pl
