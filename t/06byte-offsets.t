#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Test::Dategrep;

test_dategrep([
    '--format=rsyslog',
    '--byte-offsets',
    '--start=2014-03-20 07:34',
    '--end=2014-03-20 07:36',
    "$Bin/files/syslog01.log"
    ], <<'EOF','byte offsets');
0 126
EOF

test_dategrep([
    '--format=rsyslog',
    '--byte-offsets',
    '--start=2014-03-20 07:34',
    "$Bin/files/syslog01.log"
    ], <<'EOF','byte offsets');
0 313
EOF

done_testing();
