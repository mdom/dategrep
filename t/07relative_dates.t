#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Test::Dategrep;

# files with line before and after date range
test_dategrep [
    '--start=2014-03-20T08:15:00-0000 add -1h',
    '--end=2014-03-20T08:15:00-0000',
    "$Bin/files/syslog01.log",
  ],
  <<'EOF', 'relative dates';
2014-03-20T07:35:05Z balin anacron[1091]: Job `cron.daily' terminated
2014-03-20T07:35:05Z balin anacron[1091]: Normal exit (1 job run)
2014-03-20T07:38:05Z balin anacron[1091]: Job `cron.daily' terminated
2014-03-20T07:42:05Z balin anacron[1091]: Normal exit (1 job run)
EOF

test_dategrep [
    '--start=1 hour ago from',
    '--end=2014-03-20 08:15:00 -0000',
    "$Bin/files/syslog01.log",
  ],
  <<'EOF', 'relative dates';
dategrep: Illegal start time.
EOF

done_testing();
