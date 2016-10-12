package App::dategrep::Iterator;
use strict;
use warnings;
use Moo;
use App::dategrep::Date qw(date_to_epoch);

has multiline => ( is => 'ro', default => sub { 0 } );
has start     => ( is => 'rw', required => 1 );
has end       => ( is => 'rw', required => 1 );
has format    => ( is => 'rw', required => 1 );
has fh        => ( is => 'lazy' );
has next_line => ( is => 'rw', clearer  => 1, );
has next_date => ( is => 'rw' );

has skip_unparsable => ( is => 'ro', default => sub { 0 } );

has eof => ( is => 'rw', default => 0 );

sub print {
    my ( $self, $until ) = @_;

    $until ||= $self->end;
    my $ignore = $self->multiline || $self->skip_unparsable;

    if ( $self->next_line ) {
        print $self->next_line;
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

sub to_epoch {
    my ( $self, $line ) = @_;
    return date_to_epoch( $line, $self->format );
}

1;
