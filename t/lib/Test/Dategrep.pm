use strict;
use warnings;

BEGIN {
    $ENV{LC_TIME} = 'C';
    $ENV{TZ}      = 'GMT';
}

use Test::Output;
use App::dategrep;

sub test_dategrep {
    my ( $argv, $output, $name ) = @_;
    no warnings 'once';
    local $App::dategrep::app = 'dategrep';
    local @ARGV = @$argv if $argv;
    combined_is { App::dategrep->new->run } $output, $name;
}

1;

