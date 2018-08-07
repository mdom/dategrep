#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use IPC::Cmd qw(can_run);
use POSIX qw(tzset);
use Test::MockTime qw(set_absolute_time);

BEGIN {
    plan( skip_all => 'skip tests using tzset windows' ) if $^O eq 'MSWin32';
    tzset;
    set_absolute_time(1477661846);    # 28-10-2016
}
use Test::Dategrep;

$ENV{DATEGREP_DEFAULT_FORMAT} = 'rsyslog';

my $output = <<'EOF';
Mar 20 08:08:31 balin avahi-daemon[2488]: Invalid response packet from host 10.1.11.87.
Mar 20 08:08:31 balin avahi-daemon[2488]: Invalid response packet from host 10.1.11.87.
Mar 20 08:09:35 balin avahi-daemon[2488]: Invalid response packet from host 10.1.11.87.
EOF

test_dategrep [ '--start=Mar 20 08:08', '--end=Mar 20 08:10',
    "$Bin/files/syslog.gz" ], $output, 'test compressed files';

test_dategrep [ '--start=Mar 20 08:08', '--end=Mar 20 08:10',
    "$Bin/files/syslog.bz" ], $output, 'test compressed files';

delete $ENV{PATH};

test_dategrep [ '--start=Mar 20 08:08', '--end=Mar 20 08:10',
    "$Bin/files/syslog.gz" ], $output, 'test gzip format without gunzip';

test_dategrep [ '--start=Mar 20 08:08', '--end=Mar 20 08:10',
    "$Bin/files/syslog.bz" ], $output, 'test bzip format without bunzip';

done_testing();
