# TODO Add warning for truncated dates!

use strict;
use warnings;

package App::dategrep;
use Date::Manip::Date;
use Date::Manip::Delta;
use Pod::Usage;
use Getopt::Long;
use Fcntl ":seek";
use File::Basename qw(basename);
use base 'Exporter';
our @EXPORT_OK = qw(run);

our $VERSION = '0.14';

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

sub intervall_to_epoch {
    my ( $time, $format ) = @_;
    if ( $time =~ /^(.*) from (.*)$/ ) {
        my ( $delta, $date ) =
          ( Date::Manip::Delta->new($1), Date::Manip::Date->new($2) );
        ## TODO: $date->is_date is missing in Date::Manip::Date
        ## will be fixed in next major release
        if ( $delta->is_delta() ) { ## and $date->is_date() ) {
            return $date->calc($delta)->secs_since_1970_GMT();
        }
    }
    return date_to_epoch( $time, $format );
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
        'byte-offsets',   'debug=s',
    );
    if ( !$rc ) {
        pod2usage( -exitstatus => "NOEXIT", -verbose => 0 );
        return 2;
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
        'rsyslog' => "%b %e %H:%M:%S",
        'apache'  => "%d/%b/%Y:%T %z",
        'iso8601' => "%O%Z",
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
        my $now = Date::Manip::Date->new("now");
        $now->set( 's', 0 );
        my $ago =
          Date::Manip::Date->new( $options{'last-minutes'} . "minutes ago" );
        $ago->set( 's', 0 );
        ( $start, $end ) =
          ( $ago->secs_since_1970_GMT(), $now->secs_since_1970_GMT() );
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
		my ($fh, $byte_beg, $byte_end ) = normal_file_byte_offsets($ARGV[0], $start, $end, %options);
		if ( not defined $byte_end ) {
		    $byte_end = (stat($fh))[7];
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
                while ( my $line = $iter->() ) {
                    print $line;
                }
            }
        }
    };
    return error($@) if $@;
    return 0;
}

=pod

=item interleave_iterators( $format, @iterators )

Take a list of iterators and checks every iterator for its next
line. After sorting these lines according to their dates, print the
earliest line. I<$format> is the date specification to find dates in
lines and @iterators a list of iterators produced by I<get_iterator()>.

=cut

sub interleave_iterators {
    my ( $format, @iterators ) = @_;

    while ( @iterators = sort_iterators( $format, @iterators ) ) {
        print $iterators[0]->();
    }
    return;
}

sub get_iterator {
    my ( $filename, $start, $end, %options ) = @_;
    my $iter;
    if ( $filename eq '-' ) {
        $iter = stdin_iterator( $filename, $start, $end, %options );
    }
    elsif ( $filename =~ /\.(bz|bz2|gz|z)$/ ) {
        $iter = uncompress_iterator( $filename, $start, $end, %options );
    }
    else {
        $iter = normal_file_iterator( $filename, $start, $end, %options );
    }
    return if !$iter;
    my @buffer;
    return sub {
        my %options = @_;
        if (@buffer) {
            return $options{peek} ? $buffer[0] : shift @buffer;
        }
        my $line = $iter->();
        if ( $options{peek} and $line ) {
            push @buffer, $line;
        }
        return $line;
    };
}

sub sort_iterators {
    my ( $format, @iterators ) = @_;

    my @timestamps;
    for my $iterator (@iterators) {
        my $line = $iterator->( peek => 1 );
        
        ## remove all iterators with eof
        next if not defined $line;

        my ( $epoch, $error ) = date_to_epoch( $line, $format );
        if ( !$epoch ) {
            die "No date found in first line: $error\n";
        }
        push @timestamps, [ $epoch, $iterator ];
    }
    return map { $_->[1] } sort { $a->[0] <=> $b->[0] } @timestamps;
}

sub normal_file_byte_offsets {
    my ( $filename, $start, $end, %options ) = @_;

    open( my $fh, '<', $filename ) or die "Can't open $filename: $!\n";
    my $test_line = <$fh>;
    if ( defined($test_line) ) {
        my ( $epoch, $error ) = date_to_epoch( $test_line, $options{'format'} );
        if ($error) {
            die "No date found in first line: $error\n";
        }
        seek( $fh, 0, SEEK_SET );

        my $tell_beg = search(
            $fh, $start, $options{'format'},
            multiline => $options{multiline},
            blocksize => $options{blocksize},
        );

        if ( defined $tell_beg ) {
            my $tell_end = search(
                $fh, $end, $options{'format'},
                min_byte  => $tell_beg,
                multiline => $options{multiline},
                blocksize => $options{blocksize},
            );

            return $fh, $tell_beg, $tell_end;
        }
    }
    return;
}

sub normal_file_iterator {
    my ( $filename, $start, $end, %options ) = @_;
    my ( $fh, $tell_beg, $tell_end ) = normal_file_byte_offsets(@_);
    if ( defined($tell_beg) ) {
        seek( $fh, $tell_beg, SEEK_SET );
        return sub {
            my $line = <$fh>;
            return if defined($tell_end) && ( tell() > $tell_end );
            return $line;
        };
    }
    return;
}

sub uncompress_iterator {
    my ( $filename, $start, $end, %options ) = @_;
    my @uncompress;
    if ( $filename =~ /\.(bz|bz2)$/ ) {
        @uncompress = qw(bzcat);
    }
    elsif ( $filename =~ /\.(gz|z)$/ ) {
        @uncompress = qw(gzip -c -d);
    }
    else {
        die "unknown ending for compressed file $filename\n";
    }
    open( my $pipe, '-|', @uncompress, $filename )
      or die "Can't open @uncompress: $!\n";
    return fh_iterator( $pipe, $start, $end, %options );
}

sub stdin_iterator {
    my ( $filename, $start, $end, %options ) = @_;
    return fh_iterator( \*STDIN, $start, $end, %options );
}

sub fh_iterator {
    my ( $fh, $start, $end, %options ) = @_;
    my $last_epoch = 0;
    return sub {
      LINE: while ( my $line = <$fh> ) {
            my ( $epoch, $error ) = date_to_epoch( $line, $options{'format'} );
            if ( !$epoch ) {
                if ( $options{'multiline'} ) {
                    return $line if $last_epoch >= $start;
                }
                die "Unparsable line: $line\n";
            }
            next LINE if $epoch < $start;
            $last_epoch = $epoch;
            return if $epoch >= $end;
            if ( $epoch >= $start ) {
                return $line;
            }
        }
        return;
    };
}

sub loadconfig {
    my $configfile = shift;
    if ( not $configfile and $ENV{HOME} ) {
        $configfile = "$ENV{HOME}/.dategreprc";
    }
    if ( not defined $configfile or not -e $configfile ) {
        return;
    }

    my ( %config, $section );
    open( my $cfg_fh, '<', $configfile )
      or die "Can't open config file: $!\n";
    while (<$cfg_fh>) {
        next if /^\s*\#/ || /^\s*$/;
        if (/^\[([^\]]*)\]\s*$/) {
            $section = lc $1;
        }
        elsif (/^(\w+)\s*=\s*(.*)/) {
            my ( $key, $val ) = ( $1, $2 );
            if ( not defined $section ) {
                die "parameter $key not in section\n";
            }
            $config{$section}->{$key} = $val;
        }
        else {
            die "Parse error in configuration file\n";
        }
    }
    return \%config;
}

{
    my $date;

    sub date_to_epoch {
        my ( $str, $format ) = @_;
        if ( !$date ) {
            $date = Date::Manip::Date->new();
        }

        my $error;
        if ($format) {
            $error = $date->parse_format( $format, $str );
        }

        if ( !$format or $error ) {
            $error = $date->parse($str);
        }

        return ( undef, $date->err ) if $error;
        return ( $date->secs_since_1970_GMT() );
    }
}

# Modified version of File::SortedSeek::_look

sub search {
    my ( $fh, $key, $format, %options ) = @_;
    return if not defined $key;
    my @stat = stat($fh) or return;
    my ( $size, $blksize ) = @stat[ 7, 11 ];
    $blksize = $options{blocksize} || $blksize || 8192;
    my $min_byte  = $options{min_byte};
    my $multiline = $options{multiline};

    # find the right block
    my ( $min, $max, $mid ) = ( 0, int( $size / $blksize ) );

    if ( defined $min_byte ) {
        $min = int( $min_byte / $blksize );
    }

  BLOCK: while ( $max - $min > 1 ) {
        $mid = int( ( $max + $min ) / 2 );
        seek( $fh, $mid * $blksize, 0 ) or return;
        <$fh> if $mid;    # probably a partial line
      LINE: while ( my $line = <$fh> ) {
            my ($epoch) = date_to_epoch( $line, $format );
            if ( !$epoch ) {
                next LINE if $multiline;

                chomp($line);
                die "Unparsable line: $line\n";
            }
            if ($multiline) {
                my $byte = tell($fh);
                $mid = int( $byte / $blksize );
            }
            $epoch < $key
              ? $min = $mid
              : $max = $mid;
            next BLOCK;
        }
    }

    # find the right line
    $min *= $blksize;
    seek( $fh, $min, 0 ) or return;
    <$fh> if $min;    # probably a partial line
    for ( ; ; ) {
        $min = tell($fh);
        defined( my $line = <$fh> ) or last;
        my ($epoch) = date_to_epoch( $line, $format );
        if ( !$epoch ) {
            next if $multiline;
            chomp($line);
            die "Unparsable line: $line\n";
        }
        if ( $epoch >= $key ) {
            seek( $fh, $min, 0 );
            return $min;
        }
    }
    return;
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
