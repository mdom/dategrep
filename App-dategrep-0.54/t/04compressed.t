#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Test::Dategrep;
use IPC::Cmd qw(can_run);

$ENV{DATEGREP_DEFAULT_FORMAT} = 'rsyslog';

SKIP: {
    skip 'gzip not installed', 1 unless can_run("gzip");

    test_dategrep [ '--start=Mar 20 08:08', '--end=Mar 20 08:10',
        "$Bin/files/syslog.gz" ],
      <<'EOF', 'test compressed files';
Mar 20 08:08:31 balin avahi-daemon[2488]: Invalid response packet from host 10.1.11.87.
Mar 20 08:08:31 balin avahi-daemon[2488]: Invalid response packet from host 10.1.11.87.
Mar 20 08:09:35 balin avahi-daemon[2488]: Invalid response packet from host 10.1.11.87.
EOF
}

SKIP: {
    skip 'bzcat not installed', 1 unless can_run("bzcat");

    test_dategrep [ '--start=Mar 20 08:08', '--end=Mar 20 08:10',
        "$Bin/files/syslog.bz" ],
      <<'EOF', 'test compressed files';
Mar 20 08:08:31 balin avahi-daemon[2488]: Invalid response packet from host 10.1.11.87.
Mar 20 08:08:31 balin avahi-daemon[2488]: Invalid response packet from host 10.1.11.87.
Mar 20 08:09:35 balin avahi-daemon[2488]: Invalid response packet from host 10.1.11.87.
EOF
}

done_testing();
