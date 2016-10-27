package App::dategrep;

use Moo;
use warnings;

use App::dategrep::Iterators;
use App::dategrep::Date;
use Config::Tiny;
use Pod::Usage;
use Getopt::Long;
use File::Basename qw(basename);

our $VERSION = '0.58';

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

has 'date' => ( is => 'rw', default => sub { App::dategrep::Date->new } );

sub run {
    my $self = shift;
    my %options;

    my $rc = GetOptions(
        \%options,        'start|from=s',
        'end|to=s',       'format=s@',
        'last-minutes=i', 'multiline!',
        'blocksize=i',    'help|?',
        'sort-files',     'man',
        'configfile=s',   'interleave',
        'byte-offsets',   'debug=s',
        'version!',       'skip-unparsable!',
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

    if ( exists $config->{formats} ) {
        $self->date->add_format( values %{ $config->{formats} } );
    }

    if ( $ENV{DATEGREP_DEFAULT_FORMAT} ) {
        $self->date->add_format( $ENV{DATEGREP_DEFAULT_FORMAT} );
    }

    $self->date->add_format( grep { /%/ } @{ $options{'format'} } );

    delete $options{'format'};    # Don't call new on iterators with format

    if ( $options{'skip-unparsable'} ) {
        $options{'multiline'} = 0;
    }

    my ( $start, $end ) = ( 0, time() );

    if ( defined $options{'start'} ) {
        ($start) = $self->date->intervall_to_epoch( $options{'start'} );
        return error("Illegal start time.") if not defined $start;
    }

    if ( defined $options{'end'} ) {
        ($end) = $self->date->intervall_to_epoch( $options{'end'} );
        return error("Illegal end time.") if not defined $end;
    }

    if ( defined $options{'last-minutes'} ) {
        ( $start, $end ) = $self->date->minutes_ago( $options{'last-minutes'} );
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
                    %options,
                    filename => $ARGV[0],
                    start    => $start,
                    end      => $end,
                    date     => $self->date,
                );
                my ( $byte_beg, $byte_end ) = $iter->byte_offsets();
                if ( not defined $byte_end ) {
                    $byte_end = ( stat( $iter->fh ) )[7];
                }
                print "$byte_beg $byte_end\n";
                return 0;
            }
        }

        my $iterators = App::dategrep::Iterators->new(
            %options,
            filenames => \@ARGV,
            start     => $start,
            end       => $end,
            date      => $self->date,
        );

        if ( $options{'interleave'} && @ARGV > 1 ) {
            $iterators->interleave();
            return 0;
        }

        if ( $options{'sort-files'} && @ARGV > 1 ) {
            $iterators->sort;
        }

        for my $iter ( $iterators->as_array ) {
            if ($iter) {
                $iter->print;
            }
        }
    };
    return error($@) if $@;
    return 0;
}

sub loadconfig {
    my $configfile = shift;
    if ( not $configfile and $ENV{HOME} ) {
        $configfile = "$ENV{HOME}/.dategreprc";
    }
    if ( not defined $configfile or not -e $configfile ) {
        return;
    }

    my $config = Config::Tiny->read($configfile);
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
