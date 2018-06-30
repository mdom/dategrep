#/usr/bin/perl

use strict;
use warnings;
use Test::More;
use StrptimePP qw(compile strptime);

$ENV{TZ} = 'GMT';

is( compile("%%"),   qr(%)x );
is( compile("foo"),  qr(foo)x );
is( compile("foo*"), qr(foo\*)x );

eval { strptime( '2018-06-30T12:12:12', '%1' ) };
like( $@, qr(^Unknown conversion specification 1) );

is( strptime( '2018-06-30T12:12:12', '%Y-%m-%dT%H:%M:%S' ),
    1530360732, 'test ISO 8601' );
is( strptime( '2018-06-30T12:12:12', '%FT%H:%M:%S' ),  1530360732, 'test %F' );
is( strptime( '2018-06-30T12:12:12', '%FT%T' ),        1530360732, 'test %T' );
is( strptime( '2018-06-30 12:12:12', '%F%t%H:%M:%S' ), 1530360732, 'test %t' );
is( strptime( '2018-06-30     12:12:12', '%F%t%H:%M:%S' ),
    1530360732, 'test %t' );

done_testing;
