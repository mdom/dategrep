#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Test::Dategrep;

$ENV{DATEGREP_DEFAULT_FORMAT} = 'rsyslog';

my $have_zcat = eval {
    no warnings;
    open( my $zcat, '-|', 'zcat',"$Bin/files/syslog.gz" ) or die;
    close $zcat;
    1;
};

my $have_bzcat = eval {
    no warnings;
    open( my $zcat, '-|', 'bzcat',"$Bin/files/syslog.bz" ) or die;
    close $zcat;
    1;
};

SKIP: {
    skip 'zcat not installed', 1 unless $have_zcat;

    test_dategrep [ '--start=Mar 20 08:08', '--end=Mar 20 08:10',
        "$Bin/files/syslog.gz" ],
      <<'EOF', 'test compressed files';
Mar 20 08:08:31 balin avahi-daemon[2488]: Invalid response packet from host 10.1.11.87.
Mar 20 08:08:31 balin avahi-daemon[2488]: Invalid response packet from host 10.1.11.87.
Mar 20 08:09:35 balin avahi-daemon[2488]: Invalid response packet from host 10.1.11.87.
EOF
}

SKIP: {
    skip 'bzcat not installed', 1 unless $have_bzcat;

    test_dategrep [ '--start=Mar 20 08:08', '--end=Mar 20 08:10',
        "$Bin/files/syslog.bz" ],
      <<'EOF', 'test compressed files';
Mar 20 08:08:31 balin avahi-daemon[2488]: Invalid response packet from host 10.1.11.87.
Mar 20 08:08:31 balin avahi-daemon[2488]: Invalid response packet from host 10.1.11.87.
Mar 20 08:09:35 balin avahi-daemon[2488]: Invalid response packet from host 10.1.11.87.
EOF
}

done_testing();
