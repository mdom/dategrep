package App::dategrep::Iterator;
use strict;
use warnings;
use Moo;
use App::dategrep::Date qw(date_to_epoch);

has 'multiline' => ( is => 'ro', default => sub { 0 } );
has 'start' => ( is => 'rw', required => 1 );
has 'end'   => ( is => 'rw', required => 1 );
has 'format' => ( is => 'rw', required => 1 );
has 'fh' => ( is => 'lazy' );
has 'skip_unparsable' => ( is => 'ro', default => sub { 0 } );

has 'next_line' => (
    is      => 'rw',
    clearer => 1,
);

sub peek {
    my $self = shift;
    if ( not defined $self->next_line ) {
        $self->next_line( $self->fh->getline );
    }
    return $self->next_line;
}

sub next_line_has_date {
    my $self = shift;
    my ($epoch) = date_to_epoch( $self->peek, $self->format );
    return defined $epoch;
}

sub getline {
    my $self = shift;
    my $next_line = $self->next_line();
    if ( defined $next_line ) {
        $self->clear_next_line();
        return $next_line;
    }
    return $self->fh->getline;
};

1;
