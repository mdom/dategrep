package App::dategrep::Iterator;
use Moo;
use Fcntl ':seek';
use File::stat;
use App::dategrep::Date;

has multiline => ( is => 'ro', default => sub { 0 } );
has format    => ( is => 'rw' );
has fh        => ( is => 'lazy' );
has start     => ( is => 'rw', default => sub { 0 } );
has end       => ( is => 'rw', default => sub { time } );
has next_line => ( is => 'rw', clearer => 1, );
has next_date => ( is => 'rw' );
has date => ( is => 'rw', default => sub { App::dategrep::Date->new } );

has skip_unparsable => ( is => 'ro', default => sub { 0 } );

has eof => ( is => 'rw', default => sub { 0 } );

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
        my ( $date, $error ) = $self->date->to_epoch($line);
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
    if ( !$self->format ) {
        my $format = $self->date->guess_format($line);
        if ($format) {
            $self->format($format);
        }
        else {
            return;
        }
    }
    return $self->date->to_epoch( $line, $self->format, prefer_past => 1 );
}

1;
