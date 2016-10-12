package App::dategrep::Iterator::Fh;
use strict;
use warnings;
use Moo;
use FileHandle;
extends 'App::dategrep::Iterator';

sub can_seek { 0 }

sub seek {
    my $self = shift;
    my $ignore = $self->multiline || $self->skip_unparsable;
    while (1) {
        my $line = $self->fh->getline;
        if ( !$line ) {
            $self->eof(1);
            return;
        }
        my ( $date, $error ) = $self->to_epoch($line);

        if ( !$date && $ignore ) {
            next;
        }
        elsif ( !$date ) {
            die "No date found in line $line";
        }
        elsif ( $date < $self->start ) {
            next;
        }
        elsif ( $date >= $self->start && $date < $self->end ) {
            $self->next_line($line);
            $self->next_date($date);
            return;
        }
        else {
            $self->eof(1);
            return;
        }
    }
}

1;
