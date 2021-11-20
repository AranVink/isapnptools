#!/usr/bin/perl
#
# run_tests.pl
#
# $Header: /home/omer/work/cvs_repository/capital/isapnptools/test/run_tests.pl,v 1.1 1999/11/11 10:18:42 omer Exp $
#
# Perl script for testing pnpdump by running run_pnpdump_test.pl
# several times, over a list of test cases provided at stdin.
#
# Copyright (C) 1999 by Omer Zak
# Licensed for general use under the GPL (version 2 or later).
#
#
# Usage:
# ls t0*.dat | run_tests.pl /bin/pnpdump
#
# where t0*.dat expands to a list of all test case files which we
# want to test.
#
######### Parameters ################################################
$test_script = "./run_pnpdump_test.pl -r $ARGV[0]";

############## Default command line option settings #################

$| = 1;       # Always auto-flush stdout.
################### Run the test cases ##############################

while (<STDIN>) {
    $case = $_;
    chop $case;
    print "Running test $case\n";
    $st = system("$test_script < $case");
    if (0 != $st) {
	die "The test case $case was aborted.\n";
    }
}

#####################################################################
# End of run_tests.pl
