#!/usr/bin/perl

use strict;
use warnings;
use Test::MockTime qw(set_absolute_time);
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Test::Dategrep;
use POSIX qw(tzset);

plan( skip_all => 'skip tests using tzset windows' ) if $^O eq 'MSWin32';
tzset;

set_absolute_time(1533625650);

test_dategrep [ '--from=2018-12-01', '--to=2019-01-10',
    "$Bin/files/syslog_year.log" ],
  <<'EOF';
Dec 30 09:20:01 foobar /bsd: acpicpu at acpi0 not configured
Jan 01 09:20:01 foobar /bsd: acpipwrres at acpi0 not configured
EOF

done_testing();
