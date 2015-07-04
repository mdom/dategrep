#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Test::Dategrep;

$ENV{DATEGREP_DEFAULT_FORMAT} = '%Y-%m-%d %H:%M';

test_dategrep [
    '--start=2014-03-23 14:16', '--end=2014-03-23 14:18',
    '--multiline',              "$Bin/files/multiline01.log"
  ],
  <<'EOF', 'test --multiline';
2014-03-23 14:16 line 1
                 more information
2014-03-23 14:17 line 1
                 more information
EOF

{
    my $stdin = <<'EOF';
2014-03-23 14:13 line 1
                 more
                 more
                 more
2014-03-23 14:15 line 1
                 more
                 more
2014-03-23 14:16 line 1
                 more
                 more
2014-03-23 16:16 line 1
                 more
                 more
EOF
    open( my $stdin_fh, '<', \$stdin );
    local *STDIN = $stdin_fh;

    test_dategrep(
        [ '--end=2014-03-23 14:15', '--start=2014-03-23 14:17', '--multiline' ],
        <<'EOF', 'read from stdin without files' );
2014-03-23 14:15 line 1
                 more
                 more
2014-03-23 14:16 line 1
                 more
                 more
EOF
}

done_testing();
