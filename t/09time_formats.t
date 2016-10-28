#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use App::dategrep::Date;
use POSIX qw(tzset);
use Test::MockTime qw(set_absolute_time);

plan( skip_all => 'skip tests using tzset windows' ) if $^O eq 'MSWin32';

$ENV{TZ} = 'GMT';
tzset;

set_absolute_time(1477656653);

my $date = App::dategrep::Date->new;

is( $date->to_epoch('2016-10-28_13:13:00.00000'),
    1477660380, 'parse svlogd -tt' );
is( $date->to_epoch('2016-10-28T13:13:00.00000'),
    1477660380, 'parse svlogd -ttt' );
is( $date->to_epoch('28/Oct/2016:13:13:00 +0000'), 1477660380, 'parse apache' );
is( $date->to_epoch('Oct 28 13:13:00'), 1477660380, 'parse rsyslogd format' );

done_testing;
