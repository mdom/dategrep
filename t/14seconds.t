#/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Test::Output;
use Test::Dategrep;
use Test::MockTime qw(set_absolute_time);
use POSIX qw(tzset);

BEGIN {
    $ENV{LC_ALL} = 'C';
    $ENV{TZ}     = 'GMT';
}

plan( skip_all => 'skip tests using tzset windows' ) if $^O eq 'MSWin32';
tzset;

set_absolute_time(1582617903);

test_dategrep [
    '--format=%H:%M:%S', '--start=11:58:12',
    '--end=12:02:31',    "$Bin/files/seconds.log"
  ],
  <<'EOF', 'handle formats with seconds';
[2020-02-24 11:58:12,007] ...
[2020-02-24 12:00:01,494] ...
[2020-02-24 12:01:01,494] ...
[2020-02-24 12:02:30,494] ...
EOF

done_testing;
