package StrptimePP;
use strict;
use warnings;
use parent 'Exporter';
use Time::Local 'timelocal', 'timegm';
use Carp 'croak';

our @EXPORT_OK = qw(compile strptime);

## TODO prefer past

sub strptime {
    my ( $string, $format ) = @_;
    my @now = localtime;
    my $re  = compile($format);
    if ( $string =~ $re ) {
        my %match = %+;
        if ( $match{month} ) {
            $match{month}--;
        }

        ## TODO Perl version //
        my @args = (
            $match{seconds} // 0,
            $match{minutes} // 0,
            $match{hours}   // 0,
            $match{day}     // $now[3],
            $match{month}   // $now[4],
            $match{year}    // $now[5],
        );
        my $tz = $match{time_zone};
        if ($tz) {
            if ( $tz eq 'UTC' || $tz eq 'GMT' || $tz eq 'Z' ) {
                return timegm(@args);
            }
            elsif ( $tz =~ /^[+-]/ ) {
                my $t = timegm(@args);
                my $offset =
                  ( ( $match{offset_hours} || 0 ) * 3600 +
                      ( $match{offset_minutes} || 0 ) * 60 ) *
                  ( $match{offset_op} eq '+' ? -1 : 1 );
                return $t + $offset;
            }
            else {
                ## TODO won't work on windows, needs POSIX::tzset()
                local $ENV{TZ} = $tz;
                return timelocal(@args);
            }
        }
        return timelocal(@args);
    }
    return;
}

my $hours     = "0[0-9] | 1[0-9] | 2[0-3]";
my $minutes   = "0[0-9] | [1-5][0-9]";
my $seconds   = "0[0-9] | [1-5][0-9]";
my $year      = "\\d{4}";
my $month     = "0[1-9] | 1[012]";
my $day       = "0?[1-9] | [12][0-9] | 3[01]";
my $time_zone = qq{
        (?<time_zone>
              [A-Za-z]+
            | (?<offset_op>[+-]) (?<offset_hours>$hours)
            | (?<offset_op>[+-]) (?<offset_hours>$hours):?(?<offset_minutes>$minutes)
        )
};

my %patterns = (
    H   => "(?<hours> $hours)",
    M   => "(?<minutes> $minutes)",
    S   => "(?<seconds> $seconds)",
    d   => "(?<day> $day )",
    m   => "(?<month> $month)",
    Y   => "(?<year> $year)",
    t   => "\\s+",
    z   => $time_zone,
    Z   => "${time_zone}?",
    R   => "(?<hours>$hours):(?<minutes>$minutes)",
    T   => "(?<hours>$hours):(?<minutes>$minutes):(?<seconds>$seconds)",
    F   => "(?<year>$year)-(?<month>$month)-(?<day>$day)",
    '%' => '%',
);

sub compile {
    my ($format) = @_;
    my $re = '';
    while (1) {
        if ( $format =~ /\G%(.)/gcx ) {
            if ( exists $patterns{$1} ) {
                $re .= $patterns{$1};
            }
            else {
                croak "Unknown conversion specification $1\n";
            }
        }
        elsif ( $format =~ /\G(.+?)(?=%)/gcx ) {
            $re .= "\Q$1\E";
        }
        elsif ( $format =~ /\G(.+?)$/gcx ) {
            $re .= "\Q$1\E";
        }
        else {
            last;
        }
    }
    return qr($re)x;
}

1;
