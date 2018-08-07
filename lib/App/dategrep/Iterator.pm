package App::dategrep::Iterator;
use strict;
use warnings;
use App::dategrep::Date;
use IPC::Cmd 'can_run';
use App::dategrep::Iterator::File;
use App::dategrep::Iterator::Stream;
use App::dategrep::Strptime;

my @filter = (
    {
        re    => qr/\.(bz|bz2)$/,
        args  => ['bzcat'],
        class => 'IO::Uncompress::Bunzip2'
    },
    {
        re    => qr/\.(gz|z)$/,
        args  => [ 'gzip', '-c', '-d' ],
        class => 'IO::Uncompress::Gunzip'
    },
);

sub match_filter {
    my ($filename) = @_;
    for my $filter (@filter) {
        if ( $filename =~ $filter->{re} ) {
            return $filter;
        }
    }
    return;
}

sub new {
    my ( $class, @args ) = @_;
    my $self     = {@args};
    my $filename = $self->{filename};

    if ( $filename eq '-' ) {
        $self->{fh} = \*STDIN;
        $class .= '::Stream';
    }
    elsif ( my $filter = match_filter($filename) ) {
        if ( $^O eq 'MSWin32' or !can_run( $filter->{args}->[0] ) ) {
            eval "require $filter->{class}";    ## no critic
            open( my $fh, '<', $filename )
              or die "Can't open $filename: $!\n";
            $self->{fh} = $filter->{class}->new($fh);
        }
        else {
            open( $self->{fh}, '-|', @{ $filter->{args} }, $filename )
              or die "Can't open @{ $filter->{args} }: $!\n";
        }
        $class .= '::Stream';
    }
    else {
        open( $self->{fh}, '<', $filename )
          or die "Can't open $filename: $!\n";
        $class .= '::File';
    }

    bless $self, $class;
    $self->skip_to_start;
    return $self;
}

sub print {
    my ( $self, $until ) = @_;

    $until ||= $self->{end};
    my $ignore = $self->{multiline} || $self->{skip_unparsable};

    if ( $self->{next_line} ) {
        print $self->{next_line};
    }

    while (1) {
        my $line = $self->{fh}->getline;
        if ( !$line ) {
            $self->{eof} = 1;
            return;
        }
        my ( $date, $error ) = $self->to_epoch($line);
        if ($date) {

            $self->{next_line} = $line;
            $self->{next_date} = $date;

            if ( $date >= $self->{end} ) {
                $self->{eof} = 1;
                return;
            }
            elsif ( $date >= $until ) {
                return;
            }
            elsif ( $date < $self->{start} ) {
                next;
            }
            else {
                print $line;
            }
        }
        elsif ( $self->{multiline} ) {
            print $line;
        }
        elsif ( $self->{skip_unparsable} ) {
            next;
        }
        else {
            die "No date found in line $line";
        }
    }
    return;
}

sub format_has_year {
    App::dategrep::Strptime::has_year( shift->{format} );
}

sub to_epoch {
    my ( $self, $line ) = @_;
    if ( !$self->{format} ) {
        my $format = $self->{date}->guess_format($line);
        if ($format) {
            $self->{format} = $format;
        }
        else {
            return;
        }
    }

    my $seconds =
      $self->{date}->to_epoch( $line, $self->{format} );

    if (   $seconds
        && $self->{next_date}
        && $self->{next_date} > $seconds
        && !$self->format_has_year )
    {
        $seconds = $self->{date}->to_epoch( $line, $self->{format},
            { year => ( localtime( $self->{next_date} ) )[5] + 1 } );
    }
    return $seconds;
}

1;
