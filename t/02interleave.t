#!/usr/bin/perl

use strict;
use warnings;
use Test::Command::Simple;
use Test::More;
use FindBin qw($Bin);

my @lines;
$ENV{DATEGREP_DEFAULT_FORMAT} = '%Y-%m-%d %H:%M';

# files with line before and after date range
run_ok(
    './bin/dategrep',
    '--start=2014-03-23 12:00',
    '--end=2014-03-23 18:00',
    '--interleave',
    "$Bin/files/interleave01.log",
    "$Bin/files/interleave02.log",
    "$Bin/files/interleave03.log",
);
(@lines) = split( /\n/, stdout() );
chomp(@lines);

my @expected_lines = (
'2014-03-23 14:09 line 1',
'2014-03-23 14:14 line 1',
'2014-03-23 14:17 line 1',
'2014-03-23 14:31 line 1',
'2014-03-23 14:51 line 1',
'2014-03-23 17:06 line 1',
);

is_deeply(\@lines,\@expected_lines,'--interleave');

done_testing();
