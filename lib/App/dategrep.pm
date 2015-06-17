use strict;
use warnings;

package App::dategrep;
use App::dategrep::Date qw(intervall_to_epoch date_to_epoch minutes_ago);
use App::dategrep::Iterator::File;
use App::dategrep::Iterator::Stdin;
use App::dategrep::Iterator::Uncompress;
use Config::Tiny;
use Pod::Usage;
use Getopt::Long;
use Fcntl ":seek";
use File::Basename qw(basename);
use base 'Exporter';
our @EXPORT_OK = qw(run);

our $VERSION = '0.51';

our $app;

BEGIN {
    $app = basename($0);
}

sub error {
    my ( $msg, $rc ) = @_;
    $rc = defined $rc ? $rc : 1;
    chomp($msg);
    warn "$app: $msg\n";
    return $rc;
}

sub run {
    my %options;
    if ( $ENV{DATEGREP_DEFAULT_FORMAT} ) {
        $options{format} = $ENV{DATEGREP_DEFAULT_FORMAT};
    }

    my $rc = GetOptions(
        \%options,        'start|from=s', 'end|to=s',     'format=s',
        'last-minutes=i', 'multiline!',   'blocksize=i',  'help|?',
        'sort-files',     'man',          'configfile=s', 'interleave',
        'byte-offsets',   'debug=s', 'version!',
    );
    if ( !$rc ) {
        pod2usage( -exitstatus => "NOEXIT", -verbose => 0 );
        return 2;
    }

    if ( $options{version} ) {
        print "$VERSION\n";
        return 0;
    }

    if ( $options{help} ) {
        pod2usage( -verbose => 1, -exitstatus => 'NOEXIT' );
        return 0;
    }
    if ( $options{man} ) {
        pod2usage( -exitstatus => "NOEXIT", -verbose => 2 );
        return 0;
    }

    my $config = loadconfig( $options{configfile} );

    my %named_formats = (
        'iso8601' => "%O%Z",
        'rsyslog' => "%b %e %H:%M:%S",
        'apache'  => "%d/%b/%Y:%T %z",
    );

    if ( exists $config->{formats} ) {
        %named_formats = ( %named_formats, %{ $config->{formats} } );
    }

    if ( not defined $options{'format'} ) {
        return error("--format is a required parameter");
    }

    if ( exists $named_formats{ $options{'format'} } ) {
        $options{'format'} = $named_formats{ $options{'format'} };
    }

    my ( $start, $end ) = ( 0, time() );

    if ( defined $options{'start'} ) {
        ($start) = intervall_to_epoch( $options{'start'}, $options{'format'} );
        return error("Illegal start time.") if not defined $start;
    }

    if ( defined $options{'end'} ) {
        ($end) = intervall_to_epoch( $options{'end'}, $options{'format'} );
        return error("Illegal end time.") if not defined $end;
    }

    if ( defined $options{'last-minutes'} ) {
        ( $start, $end ) = minutes_ago( $options{'last-minutes'} );
    }

    if ( $end < $start ) {
        ( $start, $end ) = ( $end, $start );
    }

    if ( defined $options{'debug'} && $options{'debug'} eq 'time' ) {
        print "Start: $start End: $end\n";
        return 0;
    }

    if ( !@ARGV ) {
        push @ARGV, '-';
    }

    eval {

        if ( $options{'byte-offsets'} ) {
            if ( @ARGV == 1 and -f $ARGV[0] ) {
                my $iter = App::dategrep::Iterator::File->new(
                    filename  => $ARGV[0],
                    start     => $start,
                    end       => $end,
                    multiline => $options{multiline},
                    format    => $options{format},
                );
                my ( $fh, $byte_beg, $byte_end ) = $iter->byte_offsets();
                if ( not defined $byte_end ) {
                    $byte_end = ( stat($fh) )[7];
                }
                print "$byte_beg $byte_end\n";
                return 0;
            }
        }

        my @iterators =
          map { get_iterator( $_, $start, $end, %options ) } @ARGV;


        if ( $options{'interleave'} ) {
            interleave_iterators( $options{'format'}, @iterators );
            return 0;
        }

        if ( $options{'sort-files'} ) {
            @iterators = sort_iterators( $options{'format'}, @iterators );
        }

        for my $iter (@iterators) {
            if ($iter) {
                while ( my $entry = $iter->get_entry ) {
                    print $entry;
                }
            }
        }
    };
    return error($@) if $@;
    return 0;
}

=pod 

=over 

=item guess_format( $formats, @iterators )

Check all formats in the array reference $formats against the first
line of all iterators. Return the first that matched.

=back

=cut

sub guess_format {
    my ($formats, @iterators) = @_;
    for my $iterator (@iterators) {
        my $line = $iterator->peek;
        for my $format ( @$formats ) {
            my $epoch = date_to_epoch( $line, $format );
            if ( defined $epoch ) {
                return $format;
            }
        }
    }
    return;
}

=pod

=over

=item interleave_iterators( $format, @iterators )

Take a list of iterators and checks every iterator for its next
line. After sorting these lines according to their dates, print the
earliest line. I<$format> is the date specification to find dates in
lines and @iterators a list of iterators produced by I<get_iterator()>.

=back

=cut

sub interleave_iterators {
    my ( $format, @iterators ) = @_;

    while ( @iterators = sort_iterators( $format, @iterators ) ) {
        print $iterators[0]->get_entry;
    }
    return;
}

sub get_iterator {
    my ( $filename, $start, $end, %options ) = @_;
    my ( $multiline, $format ) = @options{qw(multiline format)};
    my @args = (
        start     => $start,
        end       => $end,
        multiline => $multiline,
        format    => $format
    );
    my $iter;
    if ( $filename eq '-' ) {
        $iter = App::dategrep::Iterator::Stdin->new(@args);
    }
    elsif ( $filename =~ /\.(bz|bz2|gz|z)$/ ) {
        $iter =
          App::dategrep::Iterator::Uncompress->new( @args,
            filename => $filename );
    }
    else {
        $iter =
          App::dategrep::Iterator::File->new( @args, filename => $filename );
    }
    return $iter;
}

=pod

=over

=item sort_iterators( $format, @iterators )

Take a date format and a list of iterators and return a list of
iterators sorted by the date of their first lines. If an iterators
returns no line, it is not included in the returned list.

=back

=cut

sub sort_iterators {
    my ( $format, @iterators ) = @_;

    my @timestamps;
    for my $iterator (@iterators) {
        my $line = $iterator->peek;
        
        ## remove all iterators with eof
        next if not defined $line;

        ## TODO What should we do under --multiline?
        my ( $epoch, $error ) = date_to_epoch( $line, $format );
        if ( !$epoch ) {
            ## TODO Which iterator produced the error?
            die "No date found in first line: $error\n";
        }
        push @timestamps, [ $epoch, $iterator ];
    }
    return map { $_->[1] } sort { $a->[0] <=> $b->[0] } @timestamps;
}

sub loadconfig {
    my $configfile = shift;
    if ( not $configfile and $ENV{HOME} ) {
        $configfile = "$ENV{HOME}/.dategreprc";
    }
    if ( not defined $configfile or not -e $configfile ) {
        return;
    }

    my $config = Config::Tiny->read( $configfile );
    if ( not defined $config ) {
        die "Error while parsing configfile: " . Config::Tiny->errstr() . "\n";
    }
    return $config;
}

1;

=pod

=for stopwords dategrep DATESPEC datespec syslog apache blocksize zcat bzcat rsyslog timestamped logrotate ARGV Domgoergen merchantability configfile !syslog

=head1 NAME

App::dategrep - grep for dates

=head1 DESCRIPTION

Please read the usage and document of L<dategrep>.

=head1 SEE ALSO

L<https://metacpan.org/pod/Date::Manip>

=head1 COPYRIGHT AND LICENSE

Copyright 2014 Mario Domgoergen C<< <mario@domgoergen.com> >>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
