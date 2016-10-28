package App::dategrep::Iterator::Stdin;
use Moo;
extends 'App::dategrep::Iterator::Fh';

sub _build_fh {
    return \*STDIN;
}

1;
