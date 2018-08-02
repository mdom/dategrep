#!/usr/bin/perl

use strict;
use warnings;
use App::dategrep::Date;
use Test::More;

my @tests = (
    [ '2018-07-02T14:15Z'                           => 1530540900 ],
    [ '2018-07-02T14:15Z truncate 1h'               => 1530540000 ],
    [ '2018-07-02T14:15Z truncate 1h add 1h'        => 1530543600 ],
    [ '2018-07-02T14:15Z truncate 1h add -1h'       => 1530536400 ],
    [ '2018-07-02T14:15Z truncate 1h add -1h10m30s' => 1530535770 ],
    [ '2018-07-02T14:15Z add -1h15m'                => 1530536400 ],
    [ '2018-07-02T14:15Z add 1h45m'                 => 1530547200 ],
);

my $t = App::dategrep::Date->new;

for my $test (@tests) {
    is( $t->to_epoch_with_modifiers( $test->[0] ), $test->[1], $test->[0] );
}

done_testing;
