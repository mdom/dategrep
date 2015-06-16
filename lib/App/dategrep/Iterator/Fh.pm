package App::dategrep::Iterator::Fh;
use strict;
use warnings;
use App::dategrep::Date 'date_to_epoch';
use Moo;
use IO::Handle;
extends 'App::dategrep::Iterator';
with 'App::dategrep::Iterator::Peekable';

has fh => ( is => 'ro', required => 1 );
has eof => ( is => 'rw', default => sub { 0 } );

sub getline {
    my $self = shift;

    ## when we find the first line that was logged at $end, we
    ## just return undef and set $found_end to one. We check
    ## $found_end directly at the beginning of the iterator
    ## function. If its true, we just return undef without
    ## checking the date of the line.

    return if $self->eof();

  LINE:
    while ( my $line = $self->fh->getline ) {
        my ( $epoch, $error ) = date_to_epoch( $line, $self->format );
        if ( !$epoch ) {
            if ( $self->multiline ) {
                return $line;
            }
            die "Unparsable line: $line\n";
        }
        if ( $epoch >= $self->end ) {
            $self->eof(1);
            return;
        }

        if ( $epoch >= $self->start ) {
            return $line;
        }
    }
    return;
}

1;
