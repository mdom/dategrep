package App::dategrep::Date;
use App::dategrep::Strptime qw(strptime);

sub new {
    my ( $class, @args ) = @_;
    bless {
        formats => [
            '%b %e %H:%M:%S',         # rsyslog
            '%b %e %H:%M',            # rsyslog
            '%d/%b/%Y:%T %z',         # apache
            '%Y-%m-%dT%H:%M:%S%Z',    # iso8601
            '%Y-%m-%d %H:%M:%S%Z',    # iso8601
            '%Y-%m-%dT%H:%M%Z',       # iso8601
            '%Y-%m-%d %H:%M%Z',       # iso8601
            '%Y-%m-%d_%H:%M%Z',       # iso8601
            '%d.%m.%Y',
            '%FT%T%Z',
        ],
        now => time,
    }, $class;
}

sub add_format {
    my $self    = shift;
    my %formats = map { $_ => 1 } @{ $self->{formats} };
    my @new     = grep { !$formats{$_} } @_;
    unshift @{ $self->{formats} }, @new;
}

sub duration_to_seconds {
    my ( $self, $duration ) = @_;
    if ( $duration =~ m{ ([+-])?  (?:(\d+)h)?  (?:(\d+)m)?  (?:(\d+)s)?  }x ) {
        my ( $op, $hours, $minutes, $seconds ) =
          ( $1 || '+', $2 || 0, $3 || 0, $4 || 0 );
        return ( $hours * 3600 + $minutes * 60 + $seconds ) *
          ( $op eq '+' ? 1 : -1 );
    }
    die "Error parsing duration $duration\n";
}

sub to_epoch_with_modifiers {
    my ( $self, $spec ) = @_;
    $spec =~
/^\s*(?<time>.*?)( \s+ truncate \s+ (?<truncate>\S+?))?( \s+ add \s+ (?<add>\S+))?\s*$/x;
    my ( $time, $truncate, $add ) = @+{qw(time truncate add)};
    my $epoch;
    if ( $time eq 'now' ) {
        $epoch = time;
    }
    else {
        for ( @{ $self->{formats} }, '%T' ) {
            $epoch = strptime( $time, $_ );
            last if $epoch;
        }
    }

    return if !$epoch;

    if ($truncate) {
        my $duration = $self->duration_to_seconds($truncate);
        $epoch -= $epoch % $duration;
    }
    if ($add) {
        $epoch += $self->duration_to_seconds($add);
    }
    return $epoch;
}

sub minutes_ago {
    my ( $self, $minutes ) = @_;
    my $to = $self->{now};
    $to -= $to % 60;
    my $from = $to - $minutes * 60;
    return ( $from, $to );
}

sub guess_format {
    my ( $self, $line ) = @_;
    for my $format ( @{ $self->{formats} } ) {
        my $date = eval { strptime( $line, $format ) };
        return $format if $date;
    }
    return;
}

sub to_epoch {
    my ( $self, $line, $format, %options ) = @_;

    $format ||= $self->guess_format($line);

    if ( !$format ) {
        return ( undef, "No date found in line $line" );
    }

    my $t = eval { strptime( $line, $format ) };

    if ( !$t ) {
        return ( undef, $@ );
    }

    return $t;
}

1;
