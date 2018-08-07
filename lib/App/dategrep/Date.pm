package App::dategrep::Date;
use strict;
use warnings;
use App::dategrep::Strptime;

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
    my ( $self, $time ) = @_;

    $time =~ s/^\s+//;
    $time =~ s/\s+$//;

    my ( $truncate, $add );

    if ( $time =~ s/\s+ truncate \s+ (\S+)//x ) {
        $truncate = $1;
    }

    if ( $time =~ s/\s+ add \s+ (\S+)//x ) {
        $add = $1;
    }

    my $epoch;
    if ( $time eq 'now' ) {
        $epoch = time;
    }
    else {
        for ( @{ $self->{formats} }, '%T', '%Y-%m-%d', '%d.%m.%Y' ) {
            $epoch = eval { App::dategrep::Strptime::strptime( $time, $_ ) };
            warn "$@" if $@;
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
        my $date = eval { App::dategrep::Strptime::strptime( $line, $format ) };
        warn "$@" if $@;
        return $format if $date;
    }
    return;
}

sub to_epoch {
    my ( $self, $line, $format, $defaults ) = @_;

    $format ||= $self->guess_format($line);

    if ( !$format ) {
        return ( undef, "No date found in line $line" );
    }

    my $t = eval { App::dategrep::Strptime::strptime( $line, $format, $defaults ) };

    if ( !$t ) {
        return ( undef, $@ );
    }

    return $t;
}

1;
