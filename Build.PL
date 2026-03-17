use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'App::dategrep',
    dist_version_from   => 'bin/dategrep',
    license             => 'perl',
    requires            => {
        'Carp'          => 0,
        'Fcntl'         => 0,
        'File::Basename'=> 0,
        'File::stat'    => 0,
        'Getopt::Long'  => 0,
        'I18N::Langinfo'=> 0,
        'IPC::Cmd'      => 0,
        'POSIX'         => 0,
        'parent'        => 0,
        'Time::Local'   => 0,
        'Pod::Usage'    => 0,
    },
    test_requires       => {
        'Test::MockTime'=> 0,
        'Test::Output'  => 0,
    },
);

$builder->create_build_script;
