use 5.006;
use strict;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
    dist_name        => 'dategrep',
    dist_version_from     => 'bin/dategrep',
    configure_requires => {
        'Module::Build'  => 0,
        'Date::Manip'    => 0,
    },
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
