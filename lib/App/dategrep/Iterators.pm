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

    my @timestamps;
    for my $iterator ( $self->as_array ) {
        my $entry = $iterator->peek_entry;

        ## remove all iterators with eof
        next if not defined $entry;

        my ( $epoch, $error ) = date_to_epoch( $entry, $iterator->format );
        if ( !$epoch ) {
            ## TODO Which iterator produced the error?
            die "No date found in first line: $error\n";
        }
        push @timestamps, [ $epoch, $iterator ];
    }
    $self->iterators(
        [ map { $_->[1] } sort { $a->[0] <=> $b->[0] } @timestamps ] );
    return;
}

sub interleave {
    my $self = shift;
    while ( $self->sort, $self->iterators->[0] ) {
        print $self->iterators->[0]->get_entry;
    }
    return;
}

1;
