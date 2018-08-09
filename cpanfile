on configure => sub {
    requires 'Module::Build::Tiny', '0.035';
    requires 'perl', '5.010_001';
    requires 'Carp';
    requires 'Fcntl';
    requires 'File::Basename';
    requires 'File::stat';
    requires 'Getopt::Long';
    requires 'I18N::Langinfo';
    requires 'IPC::Cmd';
    requires 'POSIX';
    requires 'parent';
    requires 'Time::Local';
    requires 'Pod::Usage';
};

on test => sub {
    requires 'Test::MockTime';
    requires 'Test::Output';
};

on develop => sub {
    requires 'Test::CPAN::Meta';
    requires 'Test::MinimumVersion::Fast', '0.04';
    requires 'Test::PAUSE::Permissions', '0.04';
    requires 'Test::Pod', '1.41';
    requires 'Test::Spellunker', 'v0.2.7';
};
