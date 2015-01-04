#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Test::Dategrep;

test_dategrep([
    '--format=iso8601',
    '--byte-offsets',
    '--start=2014-03-20T07:34Z',
    '--end=2014-03-20T07:36Z',
    "$Bin/files/syslog01.log"
    ], <<'EOF','byte offsets');
0 136
EOF

test_dategrep([
    '--format=iso8601',
    '--byte-offsets',
    '--start=2014-03-20T07:34Z',
    "$Bin/files/syslog01.log"
    ], <<'EOF','byte offsets');
0 338
EOF

done_testing();
