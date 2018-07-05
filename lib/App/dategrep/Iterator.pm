package App::dategrep::Iterator;
use strict;
use warnings;
use Fcntl ':seek';
use File::stat;
use App::dategrep::Date;
use IPC::Cmd 'can_run';

sub new {
    my ( $class, @args ) = @_;
    my $self = bless {@args}, $class;

    if ( $self->{filename} eq '-' ) {
        $self->{fh} = \*STDIN;
        $self->fake_seek;
    }
    elsif ( $self->{filename} =~ /\.(bz|bz2)$/ ) {
        if ( $^O eq 'MSWin32' or !can_run('bzcat') ) {
            require IO::Uncompress::Bunzip2;
            $self->{fh} = IO::Uncompress::Bunzip2->new( $self->{filename} );

        }
        else {
            my @uncompress = qw(bzcat);
            open( $self->{fh}, '-|', @uncompress, $self->{filename} )
              or die "Can't open @uncompress: $!\n";
        }
        $self->fake_seek;
    }
    elsif ( $self->{filename} =~ /\.(gz|z)$/ ) {
        if ( $^O eq 'MSWin32' or !can_run('gzip') ) {
            require IO::Uncompress::Gunzip;
            $self->{fh} = IO::Uncompress::Gunzip->new( $self->{filename} );
        }
        else {
            my @uncompress = qw(gzip -c -d);
            open( $self->{fh}, '-|', @uncompress, $self->{filename} )
              or die "Can't open @uncompress: $!\n";
        }
        $self->fake_seek;
    }
    else {
        open( $self->{fh}, '<', $self->{filename} )
          or die "Can't open $self->{filename}: $!\n";
        $self->seek;
    }
    return $self;
}

sub fake_seek {
    my $self = shift;
    my $ignore = $self->{multiline} || $self->{skip_unparsable};
    while (1) {
        my $line = $self->{fh}->getline;
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
        elsif ( $date < $self->{start} ) {
            next;
        }
        elsif ( $date >= $self->{start} && $date < $self->{end} ) {
            $self->{next_line} = $line;
            $self->{next_date} = $date;
            return;
        }
        else {
            $self->eof(1);
            return;
        }
    }
}

sub print {
    my ( $self, $until ) = @_;

    $until ||= $self->{end};
    my $ignore = $self->{multiline} || $self->{skip_unparsable};

    if ( $self->{next_line} ) {
        print $self->{next_line};
    }

    while (1) {
        my $line = $self->{fh}->getline;
        if ( !$line ) {
            $self->{eof} = 1;
            return;
        }
        my ( $date, $error ) = $self->{date}->to_epoch($line);
        if ($date) {

            $self->{next_line} = $line;
            $self->{next_date} = $date;

            if ( $date >= $self->{end} ) {
                $self->{eof} = 1;
                return;
            }
            elsif ( $date >= $until ) {
                return;
            }
            elsif ( $date < $self->{start} ) {
                next;
            }
            else {
                print $line;
            }
        }
        elsif ( $self->{multiline} ) {
            print $line;
        }
        elsif ( $self->{skip_unparsable} ) {
            next;
        }
        else {
            die "No date found in line $line";
        }
    }
    return;
}

sub to_epoch {
    my ( $self, $line ) = @_;
    if ( !$self->{format} ) {
        my $format = $self->{date}->guess_format($line);
        if ($format) {
            $self->{format} = $format;
        }
        else {
            return;
        }
    }
    return $self->{date}->to_epoch( $line, $self->{format}, prefer_past => 1 );
}

sub seek {
    my $self = shift;

    my $min = $self->search( $self->{start} );

    if ( not defined $min ) {
        $self->{eof} = 1;
        return;
    }

    my $line = $self->{fh}->getline;
    my ( $date, $error ) = $self->to_epoch($line);

    if ( $date >= $self->{end} ) {
        $self->{eof} = 1;
        return;
    }

    $self->{next_line} = $line;
    $self->{next_date} = $date;
    return;
}

sub search {
    my $self = shift;
    my ( $key, $min_byte ) = @_;
    my $fh = $self->{fh};

    my $size            = stat($fh)->size;
    my $blksize         = stat($fh)->blksize || 8192;
    my $multiline       = $self->{multiline};
    my $skip_unparsable = $self->{skip_unparsable};

    # find the right block
    my ( $min, $max, $mid ) = ( 0, int( $size / $blksize ) );

    if ( defined $min_byte ) {
        $min = int( $min_byte / $blksize );
    }

  BLOCK: while ( $max - $min > 1 ) {
        $mid = int( ( $max + $min ) / 2 );
        $fh->seek( $mid * $blksize, SEEK_SET ) or return;
        $fh->getline if $mid;    # probably a partial line
      LINE: while (1) {
            my $line = $fh->getline;
            if ( !$line ) {
                ## This can happen if line size is way bigger than blocksize
                last BLOCK;
            }
            my ($epoch) = $self->to_epoch($line);
            if ( !$epoch ) {
                next LINE if $multiline || $skip_unparsable;
                die "No date found in line $line";
            }

            $epoch < $key
              ? $min = int( ( $fh->tell - length($line) ) / $blksize )
              : $max = $mid;

            next BLOCK;
        }
    }

    # find the right line
    $min *= $blksize;
    $fh->seek( $min, SEEK_SET ) or return;
    $fh->getline if $min;    # probably a partial line
    for ( ; ; ) {
        $min = $fh->tell;
        defined( my $line = $fh->getline ) or last;
        my ($epoch) = $self->to_epoch($line);
        if ( !$epoch ) {
            next if $multiline || $skip_unparsable;
            die "No date found in line $line";
        }
        if ( $epoch >= $key ) {
            $fh->seek( $min, SEEK_SET );
            return $min;
        }
    }
    return;
}

1;
