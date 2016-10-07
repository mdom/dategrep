package App::dategrep::Iterator::File;
use strict;
use warnings;
use Fcntl ":seek";
use Moo;
use FileHandle;
extends 'App::dategrep::Iterator';

has 'filename' => ( is => 'ro', required => 1 );
has 'blocksize' => ( is => 'lazy' );
has 'tell_beg'  => ( is => 'rw' );
has 'tell_end'  => ( is => 'rw' );

sub _build_blocksize {
    my $self = shift;
    return ( stat( $self->filename ) )[11] || 8192;
}

sub _build_fh {
    my $self = shift;
    my ( $fh, $tell_beg, $tell_end ) = $self->byte_offsets();
    $self->tell_beg($tell_beg);
    $self->tell_end($tell_end);
    $fh->seek( $tell_beg, SEEK_SET );
    return $fh;
}

sub get_entry_unbuffered {
    my $self = shift;
    my $line = $self->getline();
    ## TODO can $tell_end be undefined?
    return
      if defined( $self->tell_end ) && ( $self->fh->tell > $self->tell_end );
    if ( $self->multiline ) {
        while ( !$self->fh->eof && !$self->next_line_has_date ) {
            $line .= $self->getline();
        }
    }
    return $line;
}

sub byte_offsets {
    my $self     = shift;
    my $filename = $self->filename;
    open( my $fh, '<', $filename ) or die "Can't open $filename: $!\n";
    my $test_line = $fh->getline;
    if ( defined($test_line) ) {
        my ( $epoch, $error ) = $self->to_epoch($test_line);
        if ($error) {
            die "No date found in first line: $error\n";
        }
        $fh->seek( 0, SEEK_SET );

        my $tell_beg =
          $self->search( $fh, $self->start, format => $self->format, );

        if ( defined $tell_beg ) {
            my $tell_end = $self->search(
                $fh, $self->end,
                min_byte => $tell_beg,
                format   => $self->format
            );

            return $fh, $tell_beg, $tell_end;
        }
    }

    # return for empty file
    return $fh, 0, -1;
}

sub search {
    my $self = shift;
    my ( $fh, $key, %options ) = @_;
    my @stat    = $fh->stat or return;
    my $size    = $stat[7];
    my $blksize = $self->blocksize;

    my $min_byte  = $options{min_byte};
    my $multiline = $self->multiline;

    # find the right block
    my ( $min, $max, $mid ) = ( 0, int( $size / $blksize ) );

    if ( defined $min_byte ) {
        $min = int( $min_byte / $blksize );
    }

  BLOCK: while ( $max - $min > 1 ) {
        $mid = int( ( $max + $min ) / 2 );
        $fh->seek( $mid * $blksize, SEEK_SET ) or return;
        $fh->getline if $mid;    # probably a partial line
      LINE: while ( my $line = $fh->getline() ) {
            my ($epoch) = $self->to_epoch($line);
            if ( !$epoch ) {
                next LINE if $multiline || $self->skip_unparsable;

                chomp($line);
                die "Unparsable line: $line\n";
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
            next if $multiline || $self->skip_unparsable;
            chomp($line);
            die "Unparsable line: $line\n";
        }
        if ( $epoch >= $key ) {
            $fh->seek( $min, SEEK_SET );
            return $min;
        }
    }
    return;
}

1;
