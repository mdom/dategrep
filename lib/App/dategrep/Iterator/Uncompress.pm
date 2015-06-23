package App::dategrep::Iterator::Uncompress;
use strict;
use warnings;
use Moo;
use IPC::Cmd 'can_run';
extends 'App::dategrep::Iterator::Fh';

has filename => ( is => 'ro', required => 1 );
has fh => ( is => 'lazy' );

sub _build_fh {
    my $self = shift;
    my $fh;
    if ( $self->filename =~ /\.(bz|bz2)$/ ) {
        if ( $^O eq 'MSWin32' or !can_run('bzcat') ) {
            require IO::Uncompress::Bunzip2;
            $fh = IO::Uncompress::Bunzip2->new( $self->filename )

        }
        else {
            my @uncompress = qw(bzcat);
            open( $fh, '-|', @uncompress, $self->filename )
              or die "Can't open @uncompress: $!\n";
        }
    }
    elsif ( $self->filename =~ /\.(gz|z)$/ ) {
        if ( $^O eq 'MSWin32' or !can_run('gzip') ) {
            require IO::Uncompress::Gunzip;
            $fh = IO::Uncompress::Gunzip->new( $self->filename );
        }
        else {
            my @uncompress = qw(gzip -c -d);
            open( $fh, '-|', @uncompress, $self->filename )
              or die "Can't open @uncompress: $!\n";
        }
    }
    else {
        die "unknown ending for compressed file " . $self->filename . "\n";
    }
    return $fh;
}

1;
