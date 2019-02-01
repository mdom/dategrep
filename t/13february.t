#/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Test::MockTime qw(set_absolute_time);
use POSIX qw(tzset);

BEGIN {
    $ENV{LC_ALL} = 'C';
    $ENV{TZ}     = 'GMT';
}

plan( skip_all => 'skip tests using tzset windows' ) if $^O eq 'MSWin32';
tzset;

set_absolute_time(1548993183);
use App::dategrep::Strptime qw(strptime);

ok( eval { strptime( 'Jan 31 16:42:06', '%b %d %H:%M:%S' ); 1 },
    'check if month 0 is used' );

done_testing;
