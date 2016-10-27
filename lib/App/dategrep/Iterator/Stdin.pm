package App::dategrep::Iterator::Stdin;
use Moo;
extends 'App::dategrep::Iterator::Fh';

sub BUILDARGS {
    my ( $class, @args ) = @_;
    @args = ref $args[0] ? @{ $args[0] } : @args;
    return { @args, fh => \*STDIN };
}

1;
