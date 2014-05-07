#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Test::Dategrep;

test_dategrep [
    "--configfile=$Bin/files/dategreprc01", '--start=2014-03-23 14:15',
    '--end=2014-03-23 14:18',               '--format=minimal',
    "$Bin/files/test01.log"
  ],
  <<'EOF', 'test --configfile';
2014-03-23 14:15 line 1
2014-03-23 14:16 line 1
2014-03-23 14:17 line 1
EOF

delete $ENV{HOME};

test_dategrep(['--format=%Y-%m-%d %H:%M', "$Bin/files/test01.log"],<<'EOF','no configfile and empty $HOME');
2014-03-23 14:14 line 1
2014-03-23 14:15 line 1
2014-03-23 14:16 line 1
2014-03-23 14:17 line 1
EOF

done_testing();
