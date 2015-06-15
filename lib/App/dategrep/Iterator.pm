package App::dategrep::Iterator;
use strict;
use warnings;
use Moo;
use App::dategrep::Date qw(date_to_epoch);

has 'multiline' => ( is => 'ro', default => sub { 0 } );
has 'start' => ( is => 'rw', required => 1 );
has 'end'   => ( is => 'rw', required => 1 );
has 'format' => ( is => 'rw', required => 1 );
has 'fh' => ( is => 'lazy' );

1;
