#!/usr/bin/perl

use strict;
use warnings;
use Test::Command::Simple;
use Test::More;
use FindBin qw($Bin);

run('./bin/dategrep',"$Bin/files/empty");

done_testing();
