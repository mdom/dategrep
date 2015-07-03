#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Test::Dategrep;
use IPC::Cmd qw(can_run);

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
