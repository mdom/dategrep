package App::dategrep::Iterator::File;
use strict;
use warnings;
use Fcntl ":seek";
use File::stat;
use Moo;
use FileHandle;
extends 'App::dategrep::Iterator';

has filename => ( is => 'ro', required => 1 );
has blocksize => ( is => 'lazy' );

sub can_seek { 1 }

sub _build_blocksize {
    my $self = shift;
    return stat( $self->fh )->blksize || 8192;
}

sub _build_fh {
    my $self     = shift;
    my $filename = $self->filename;
    open( my $fh, '<', $filename ) or die "Can't open $filename: $!\n";
    return $fh;
}

sub seek {
    my $self = shift;

    my $min = $self->search( $self->start );

    if ( not defined $min ) {
        $self->eof(1);
        return;
    }

    my $line = $self->fh->getline;
    my ( $date, $error ) = $self->to_epoch($line);

    if ( $date >= $self->end ) {
        $self->eof(1);
        return;
    }

    $self->next_line($line);
    $self->next_date($date);
    return;
}

sub byte_offsets {
    my $self     = shift;
    my $tell_beg = $self->search( $self->start );

    if ( defined $tell_beg ) {
        my $tell_end = $self->search( $self->end, $tell_beg );
        return $tell_beg, $tell_end;
    }

    # return for empty file
    return 0, -1;
}

sub search {
    my $self = shift;
    my ( $key, $min_byte ) = @_;
    my $fh = $self->fh;

    my $size      = stat($fh)->size;
    my $blksize   = $self->blocksize;
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
      LINE: while (1) {
            my $line = $fh->getline();
            if ( !$line ) {
                ## This can happen if line size is way bigger than blocksize
                last BLOCK;
            }
            my ($epoch) = $self->to_epoch($line);
            if ( !$epoch ) {
                next LINE if $multiline || $self->skip_unparsable;
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
            next if $multiline || $self->skip_unparsable;
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
