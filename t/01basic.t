#!/usr/bin/perl

use strict;
use warnings;
use Test::Output;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Test::Dategrep;
use POSIX qw(setlocale LC_ALL);

setlocale( LC_ALL, 'C' );

test_dategrep( [ '--format=%Y', "$Bin/files/empty" ], <<'EOF', "Empty files" );
EOF

test_dategrep( [ '--unknown=%Y', "$Bin/files/empty" ],
    <<'EOF', "Unknown parameter" );
Unknown option: unknown
EOF

test_dategrep( ["$Bin/files/empty"], <<'EOF', 'missing paramter --format' );
dategrep: --format is a required parameter
EOF

test_dategrep(
    [
        '--start=32.13.2013',      '--end=01.04.2014',
        '--format=%Y-%m-%d %H:%M', "$Bin/files/empty"
    ],
    <<'EOF', 'unparsable date for --start' );
dategrep: Illegal start time.
EOF

test_dategrep(
    [
        '--end=32.13.2013',        '--start=01.04.2014',
        '--format=%Y-%m-%d %H:%M', "$Bin/files/empty"
    ],
    <<'EOF', 'unparsable date for --end' );
dategrep: Illegal end time.
EOF

test_dategrep(
    [
        '--format=%Y-%m-%d %H:%M',
        '--start=2014-03-23 14:15',
        '--end=2014-03-23 14:17',
        "$Bin/files/does_note_exists.log"
    ],
    <<"EOF", 'access missing file' );
dategrep: Can't open $Bin/files/does_note_exists.log: No such file or directory
EOF

test_dategrep(
    [
        '--format=%Y-%m-%d %H:%M',
        '--start=2014-03-23 14:15',
        '--end=2014-03-23 14:17',
        "$Bin/files/test03.log"
    ],
    <<"EOF", 'Missing date on first line' );
dategrep: No date found in first line: [parse] Invalid date string
EOF

# files with line before and after date range
test_dategrep(
    [
        '--format=%Y-%m-%d %H:%M',
        '--start=2014-03-23 14:15',
        '--end=2014-03-23 14:17',
        "$Bin/files/test01.log"
    ],
    <<'EOF', 'files with line before and after date range' );
2014-03-23 14:15 line 1
2014-03-23 14:16 line 1
EOF

test_dategrep(
    [
        '--format=%Y-%m-%d %H:%M',
        '--start=2014-03-23 14:16',
        '--end=2014-03-23 14:18',
        '--blocksize=23',
        "$Bin/files/test01.log"
    ],
    <<'EOF', 'use --blocksize' );
2014-03-23 14:16 line 1
2014-03-23 14:17 line 1
EOF

test_dategrep(
    [
        '--format=%Y-%m-%d %H:%M',
        '--start=2014-03-23 18:15',
        '--end=2014-03-23 19:17',
        "$Bin/files/test01.log"
    ],
    <<'EOF', 'files with parsable lines but not in range' );
EOF

test_dategrep [ '--format=iso8601', "$Bin/files/syslog01.log", ],
  <<'EOF', 'named formats';
2014-03-20T07:35:05Z balin anacron[1091]: Job `cron.daily' terminated
2014-03-20T07:35:05Z balin anacron[1091]: Normal exit (1 job run)
2014-03-20T07:38:05Z balin anacron[1091]: Job `cron.daily' terminated
2014-03-20T07:42:05Z balin anacron[1091]: Normal exit (1 job run)
2014-03-20T08:42:05Z balin anacron[1091]: Normal exit (1 job run)
EOF

test_dategrep [ '--format=iso8601', "$Bin/files/syslog02.log", ],
  <<'EOF', 'Unparsable line';
dategrep: Unparsable line: 2014-03-200T07:35:05Z balin anacron[1091]: Job `cron.daily' terminated
EOF

test_dategrep [ '--format=iso8601', '--skip-unparsable',
    "$Bin/files/syslog02.log", ], <<'EOF', 'Unparsable line';
2014-03-20T07:35:05Z balin anacron[1091]: Normal exit (1 job run)
2014-03-200T07:35:05Z balin anacron[1091]: Job `cron.daily' terminated
EOF

# files with every line in date range
test_dategrep( [ '--format=%Y-%m-%d %H:%M', "$Bin/files/test01.log" ],
    <<'EOF', 'files with every line in date range' );
2014-03-23 14:14 line 1
2014-03-23 14:15 line 1
2014-03-23 14:16 line 1
2014-03-23 14:17 line 1
EOF

$ENV{DATEGREP_DEFAULT_FORMAT} = '%Y-%m-%d %H:%M';
test_dategrep( ["$Bin/files/test01.log"],
    <<'EOF', 'environment variable DATEGREP_DEFAULT_FORMAT' );
2014-03-23 14:14 line 1
2014-03-23 14:15 line 1
2014-03-23 14:16 line 1
2014-03-23 14:17 line 1
EOF

test_dategrep(
    [ '--sort-files', "$Bin/files/test01.log", "$Bin/files/test02.log" ],
    <<'EOF', 'two files with --sort-files' );
2014-03-23 13:14 line 1
2014-03-23 13:15 line 1
2014-03-23 13:16 line 1
2014-03-23 13:17 line 1
2014-03-23 14:14 line 1
2014-03-23 14:15 line 1
2014-03-23 14:16 line 1
2014-03-23 14:17 line 1
EOF

test_dategrep( [ "$Bin/files/test01.log", "$Bin/files/test02.log" ],
    <<'EOF', 'same files without --sort-files' );
2014-03-23 14:14 line 1
2014-03-23 14:15 line 1
2014-03-23 14:16 line 1
2014-03-23 14:17 line 1
2014-03-23 13:14 line 1
2014-03-23 13:15 line 1
2014-03-23 13:16 line 1
2014-03-23 13:17 line 1
EOF

test_dategrep(
    [
        '--end=2014-03-23 14:15',
        '--start=2014-03-23 14:17',
        "$Bin/files/test01.log"
    ],
    <<'EOF', 'auto swap end and start if end is before start' );
2014-03-23 14:15 line 1
2014-03-23 14:16 line 1
EOF

test_dategrep(
    [
        '--end=2014-03-23T14:15Z', '--start=2014-03-23T14:17Z',
        '--debug=time',            "$Bin/files/test01.log"
    ],
    <<'EOF', 'debug time' );
Start: 1395584100 End: 1395584220
EOF

{
    my $stdin = <<'EOF';
2014-03-23 14:13 line 1
2014-03-23 14:15 line 1
2014-03-23 14:16 line 1
2014-03-23 16:16 line 1
EOF

    open( my $stdin_fh, '<', \$stdin );
    local *STDIN = $stdin_fh;

    test_dategrep( [ '--end=2014-03-23 14:15', '--start=2014-03-23 14:17', ],
        <<'EOF', 'read from stdin without files' );
2014-03-23 14:15 line 1
2014-03-23 14:16 line 1
EOF
}

{
    my $stdin = <<'EOF';
2014-03-23 14:13 line 1
2014-03-23 14:15 line 1
2014-03-23 14:16 line 1
2014-03-23 16:16 line 1
EOF
    open( my $stdin_fh, '<', \$stdin );
    local *STDIN = $stdin_fh;

    test_dategrep(
        [ '--end=2014-03-23 14:15', '--start=2014-03-23 14:17', '-' ],
        <<'EOF', 'read from stdin explicitly' );
2014-03-23 14:15 line 1
2014-03-23 14:16 line 1
EOF
}

done_testing();
