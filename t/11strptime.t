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

set_absolute_time(1514884865);

use App::dategrep::Strptime qw(strptime);

eval { strptime( '2018-06-30T12:12:12', '%1' ) };
like( $@, qr(^Unknown conversion specification 1) );

while (<DATA>) {
    chomp;
    my ( $string, $format, $epoch ) =
      map { s/^\s*//; s/\s*$//; $_ } split( /\|/, $_ );
    is( strptime( $string, $format ), $epoch, "$string -> $format" );
}

done_testing;

__DATA__
Sun, 06-Nov-1994 08:49:37 UTC | %a, %d-%B-%Y %T %Z |  784111777
Mon Jul 02                    | %a %b %d           | 1530489600
Mon Jul  2                    | %a %b %d           | 1530489600
Mon Jul  2                    | %a %b %e           | 1530489600
Oct  1 08:12:51               | %b %d %H:%M:%S     | 1538381571
2018-06-30T12:12:12Z          | %FT%T%z            | 1530360732
2018-06-30T12:12:12+02:00     | %FT%T%z            | 1530353532
2018-06-30T12:12:12CET        | %FT%T%z            | 1530353532
2018-06-30     12:12:12       | %F%t%H:%M:%S       | 1530360732
2018-06-30T12:12:12           | %Y-%m-%dT%H:%M:%S  | 1530360732
2018-06-30T12:12:12           | %FT%H:%M:%S        | 1530360732
2018-06-30T12:12:12           | %FT%T              | 1530360732
2018-06-30 12:12:12           | %F%t%H:%M:%S       | 1530360732
2018-06-30 12:12:12 PM        | %F %I:%M:%S %p     | 1530360732
2018-06-30 12:12:12 AM        | %F %I:%M:%S %p     | 1530317532
