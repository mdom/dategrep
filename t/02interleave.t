#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Test::Dategrep;

$ENV{DATEGREP_DEFAULT_FORMAT} = '%Y-%m-%d %H:%M';

# files with line before and after date range
test_dategrep [
    '--start=2014-03-23 12:00',
    '--end=2014-03-23 18:00',
    '--interleave',
    "$Bin/files/interleave01.log",
    "$Bin/files/interleave02.log",
    "$Bin/files/interleave03.log",
    ],<<'EOF','--interleave files';
2014-03-23 14:09 line 1
2014-03-23 14:14 line 1
2014-03-23 14:17 line 1
2014-03-23 14:31 line 1
2014-03-23 14:51 line 1
2014-03-23 17:06 line 1
EOF

done_testing();
