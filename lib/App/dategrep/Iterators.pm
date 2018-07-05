package App::dategrep::Iterators;
use strict;
use warnings;
use App::dategrep::Iterator;

sub as_array {
    return @{ shift->{iterators} };
}

sub new {
    my ( $class, %options ) = @_;

    my $filenames = delete $options{filenames};
    my @filenames = ref $filenames ? @$filenames : $filenames;

    my @iterators;
    for my $filename (@filenames) {
        push @iterators,
          App::dategrep::Iterator->new( %options, filename => $filename );
    }

    return bless { iterators => \@iterators }, $class;
}

sub sort {
    my $self      = shift;
    my @iterators = @{ $self->{iterators} };
    $self->{iterators} = [
        sort { $a->{next_date} <=> $b->{next_date} }
        grep { !$_->{eof} } @{ $self->{iterators} }
    ];
    return;
}

sub interleave {
    my $self = shift;

    while ( $self->sort, $self->{iterators}->[0] ) {
        my $until;
        if ( $self->{iterators}->[1] ) {
            $until = $self->{iterators}->[1]->{next_date};
        }
        $self->{iterators}->[0]->print($until);
    }
    return;
}

1;
