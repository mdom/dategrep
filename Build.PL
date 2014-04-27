use 5.006;
use strict;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
    dist_name          => 'App-dategrep',
    dist_version_from  => 'bin/dategrep',
    configure_requires => {
        'Module::Build' => 0,
    },
    build_requires => {
        'Date::Manip'  => 0,
        'Getopt::Long' => 0,
        'Pod::Usage'   => 0,
    },
    test_requires => {
        'Test::Output'   => 0,
        'Test::More'     => 0,
        'Test::MockTime' => 0,
        'FindBin'        => 0,
        'POSIX'          => 0,
    },
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
