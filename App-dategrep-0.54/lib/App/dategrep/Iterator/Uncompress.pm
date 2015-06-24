package App::dategrep::Iterator::Uncompress;
use strict;
use warnings;
use Moo;
extends 'App::dategrep::Iterator::Fh';

has filename => ( is => 'ro', required => 1 );
has fh => ( is => 'lazy' );

sub _build_fh {
    my $self = shift;
    my @uncompress;
    if ( $self->filename =~ /\.(bz|bz2)$/ ) {
        @uncompress = qw(bzcat);
    }
    elsif ( $self->filename =~ /\.(gz|z)$/ ) {
        @uncompress = qw(gzip -c -d);
    }
    else {
        die "unknown ending for compressed file " . $self->filename . "\n";
    }
    open( my $pipe, '-|', @uncompress, $self->filename )
      or die "Can't open @uncompress: $!\n";
    return $pipe;
}

1;
