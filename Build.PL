use 5.006;
use strict;
use warnings FATAL => 'all';

use Module::Build;
my $class = Module::Build->subclass(
    class => "Module::Build::Custom",
    code  => q{
sub ACTION_standalone {
    warn "This used to call ./build-standalone.sh, but it has now so many
dependencies that it is probably easier for you to just download the
standalone scripts at
https://mdom.github.io/dategrep/dategrep-standalone-big.pl or
https://mdom.github.io/dategrep/dategrep-standalone-small.pl. If you
want to build it yourself, you have to install App::fatten.\n";
    exit 0;
}
    },
);

my $builder = $class->new(
    module_name        => 'App::dategrep',
    configure_requires => {
        'Module::Build' => '0.4004',
    },
    build_requires => {
        'Date::Manip'  => 0,
        'Getopt::Long' => 0,
        'Pod::Usage'   => 0,
        'Config::Tiny' => 0,
    },
    test_requires => {
        'Test::Output'   => 0,
        'Test::More'     => 0,
        'Test::MockTime' => 0,
        'FindBin'        => 0,
        'POSIX'          => 0,
        'IPC::Cmd'       => 0,
    },
    create_makefile_pl => 'traditional',
    meta_merge         => {
        resources => {
            bugtracker => 'https://github.com/mdom/dategrep/issues',
            repository => 'https://github.com/mdom/dategrep'
        }
    },
);

$builder->create_build_script();
