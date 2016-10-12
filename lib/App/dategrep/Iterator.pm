package App::dategrep::Iterator;
use strict;
use warnings;
use Moo;
use Fcntl ':seek';
use File::stat;
use App::dategrep::Date qw(date_to_epoch %formats);

has multiline => ( is => 'ro', default => sub { 0 } );
has start     => ( is => 'rw', required => 1 );
has end       => ( is => 'rw', required => 1 );
has format    => ( is => 'rw', required => 1 );
has fh        => ( is => 'lazy' );
has next_line => ( is => 'rw', clearer  => 1, );
has next_date => ( is => 'rw' );

has skip_unparsable => ( is => 'ro', default => sub { 0 } );

has eof => ( is => 'rw', default => 0 );

sub print_all {
    my $self = shift;
    my $pos  = $self->fh->tell;

    my $max = $self->search( $self->end, $self->fh->tell );
    if ( not defined $max ) {
        $max = stat( $self->fh )->size;
    }

    $self->fh->seek( $pos, SEEK_SET );
    while ( $self->fh->tell < $max ) {
        print $self->fh->getline;
    }
    $self->eof(1);
    return;
}

sub print {
    my ( $self, $until ) = @_;

    $until ||= $self->end;
    my $ignore = $self->multiline || $self->skip_unparsable;

    if ( $self->next_line ) {
        print $self->next_line;
    }

    if ( $until >= $self->end && $self->multiline && $self->can_seek ) {
        $self->print_all;
        return;
    }

    while (1) {
        my $line = $self->fh->getline;
        if ( !$line ) {
            $self->eof(1);
            return;
        }
        my ( $date, $error ) = $self->to_epoch($line);
        if ($date) {

            $self->next_line($line);
            $self->next_date($date);

            if ( $date >= $self->end ) {
                $self->eof(1);
                return;
            }
            elsif ( $date >= $until ) {
                return;
            }
            elsif ( $date < $self->start ) {
                next;
            }
            else {
                print $line;
            }
        }
        elsif ( $self->multiline ) {
            print $line;
        }
        elsif ( $self->skip_unparsable ) {
            next;
        }
        else {
            die "No date found in line $line";
        }
    }
    return;
}

sub BUILD {
    shift->seek;
}

sub guess_format {
    my ( $self, $line ) = @_;
    for my $format ( values %formats ) {
        my ($date) = date_to_epoch( $line, $format );
        if ($date) {
            $self->format($format);
            last;
        }
    }
    return;
}

sub to_epoch {
    my ( $self, $line ) = @_;
    if ( !$self->format ) {
        $self->guess_format($line);
    }
    return date_to_epoch( $line, $self->format );
}

1;
