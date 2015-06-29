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

has 'next_entry' => (
    is      => 'rw',
    clearer => 1,
);

sub peek_line {
    my $self = shift;
    if ( not defined $self->next_line ) {
        $self->next_line( $self->fh->getline );
    }
    return $self->next_line;
}

sub peek_entry {
    my $self = shift;
    if ( not defined $self->next_entry ) {
        $self->next_entry( $self->get_entry_unbuffered );
    }
    return $self->next_entry;
}

sub next_line_has_date {
    my $self = shift;
    my ($epoch) = $self->date_to_epoch( $self->peek_line );
    return defined $epoch;
}

sub date_to_epoch {
    my ( $self, $line ) = @_;
    return date_to_epoch( $line, $self->format );
}

sub get_entry {
    my $self = shift;
    my $next_entry = $self->next_entry();
    if ( defined $next_entry ) {
        $self->clear_next_entry();
        return $next_entry;
    }
    return $self->get_entry_unbuffered;
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
