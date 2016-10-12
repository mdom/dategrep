package App::dategrep::Iterators;
use strict;
use warnings;
use Moo;
use App::dategrep::Date qw(date_to_epoch);
use App::dategrep::Iterator::File;
use App::dategrep::Iterator::Stdin;
use App::dategrep::Iterator::Uncompress;

has iterators => ( is => 'rw', default => sub { [] } );

sub as_array {
    return @{ shift->iterators };
}

sub BUILDARGS {
    my ( $class, %options ) = @_;
    my @filenames =
      ref $options{filenames} ? @{ $options{filenames} } : $options{filenames};
    my @args = (
        start           => $options{start},
        end             => $options{end},
        multiline       => $options{multiline},
        format          => $options{format},
        skip_unparsable => $options{'skip-unparsable'},
    );
    my @iterators;
    for my $filename (@filenames) {
        if ( $filename eq '-' ) {
            push @iterators, App::dategrep::Iterator::Stdin->new(@args);
        }
        elsif ( $filename =~ /\.(bz|bz2|gz|z)$/ ) {
            push @iterators,
              App::dategrep::Iterator::Uncompress->new( @args,
                filename => $filename );
        }
        else {
            push @iterators,
              App::dategrep::Iterator::File->new( @args,
                filename => $filename );
        }
    }
    return { iterators => \@iterators };
}

sub sort {
    my $self = shift;

    my @iterators = @{ $self->iterators };

    @iterators =
      sort { $a->next_date <=> $b->next_date }
      grep { !$_->eof } @iterators;

    $self->iterators( \@iterators );

    return;
}

sub interleave {
    my $self = shift;

    ## TODO
    ## 1. read a file from each iterator and set next_line and next_time
    ## 2. sort by next_time
    ## 3. print lines from lowest iterator until it's next time is higer than the second lowest iterator.
    ## 4. goto 2

    while ( $self->sort, $self->iterators->[0] ) {
        my $until;
        if ( $self->iterators->[1] ) {
            $until = $self->iterators->[1]->next_date;
        }
        $self->iterators->[0]->print($until);
    }
    return;
}

1;
