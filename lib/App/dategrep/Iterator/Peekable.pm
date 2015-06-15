package App::dategrep::Iterator::Peekable;
use strict;
use warnings;
use Moo::Role;

requires 'getline';

has 'buffer' => (
    is      => 'rw',
    clearer => 1,
);

sub peek {
    my $self = shift;
    if ( not defined $self->buffer ) {
        $self->buffer( $self->fh->getline );
    }
    return $self->buffer;
}

around 'getline' => sub {
    my $orig = shift;
    my ($self) = @_;
    my $buffer = $self->buffer();
    if ( defined $buffer ) {
        $self->clear_buffer();
        return $buffer;
    }
    return $orig->(@_);
};

1;
