package App::dategrep::Strptime;

use strict;
use warnings;
use parent 'Exporter';
use Time::Local 'timelocal', 'timegm';
use Carp 'croak';
our @EXPORT_OK = qw(strptime);
use POSIX 'locale_h';
use POSIX 'strftime';
use I18N::Langinfo qw(langinfo
  ABDAY_1 ABDAY_2 ABDAY_3 ABDAY_4 ABDAY_5 ABDAY_6 ABDAY_7
  ABMON_1 ABMON_2 ABMON_3 ABMON_4 ABMON_5 ABMON_6 ABMON_7 ABMON_8 ABMON_9 ABMON_10 ABMON_11 ABMON_12
  DAY_1 DAY_2 DAY_3 DAY_4 DAY_5 DAY_6 DAY_7
  MON_1 MON_2 MON_3 MON_4 MON_5 MON_6 MON_7 MON_8 MON_9 MON_10 MON_11 MON_12
  D_T_FMT AM_STR PM_STR
);

setlocale( LC_TIME, "" );

my $i = 1;
my %abbrevated_weekdays =
  map { langinfo($_) => $i++ } ABDAY_1, ABDAY_2, ABDAY_3, ABDAY_4, ABDAY_5,
  ABDAY_6, ABDAY_7;

$i = 1;
my %abbrevated_months =
  map { langinfo($_) => $i++ } ABMON_1, ABMON_2, ABMON_3, ABMON_4, ABMON_5,
  ABMON_6, ABMON_7, ABMON_8, ABMON_9,
  ABMON_10, ABMON_11, ABMON_12;

$i = 1;
my %weekdays = map { langinfo($_) => $i++ } DAY_1, DAY_2, DAY_3, DAY_4, DAY_5,
  DAY_6, DAY_7;

$i = 1;
my %months = map { langinfo($_) => $i++ } MON_1, MON_2, MON_3, MON_4, MON_5,
  MON_6, MON_7, MON_8, MON_9, MON_10, MON_11, MON_12;

my $weekday_name_re = join( '|', keys %abbrevated_weekdays, keys %weekdays );
my $month_name_re   = join( '|', keys %abbrevated_months,   keys %months );

## TODO prefer past

sub strptime {
    my ( $string, $format ) = @_;
    my @now = localtime;
    my $re  = compile($format);
    if ( $string =~ $re ) {
        my %match = %+;

        if ( my $month_name = $match{month_name} ) {
            $match{month} =
              $months{$month_name} || $abbrevated_months{$month_name};
            if ( !$match{month} ) {
                croak "Illegal month name $month_name\n";
            }
        }
        if ( $match{month} ) {
            $match{month}--;
        }

        if ( $match{hours} && $match{hours} <= 12 ) {
            if ( $match{am} ) {
                if ( $match{hours} == 12 ) {
                    $match{hours} = 0;
                }
            }
            elsif ( $match{pm} ) {
                if ( $match{hours} < 12 ) {
                    $match{hours} += 12;
                }
            }
        }

        if ( $match{short_year} and !$match{year} ) {
            if ( $match{century} ) {
                $match{year} = $match{century} * 1000 + $match{short_year};
            }
            else {
                if ( $match{short_year} < 69 ) {
                    $match{year} = 1900 + $match{short_year};
                }
                else {
                    $match{year} = 2000 + $match{short_year};
                }
            }
        }

        ## TODO Perl version //
        my @args = (
            $match{seconds} // 0,
            $match{minutes} // 0,
            $match{hours} // 0,
            $match{day} // $now[3],
            $match{month} // $now[4],
            $match{year} // $now[5],
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

my $hours     = "[0 ][0-9] | 1[0-9] | 2[0-3]";
my $hours_12  = "[0 ][0-9] | 1[0-2]";
my $minutes   = "[0 ][0-9] | [1-5][0-9]";
my $seconds   = "[0 ][0-9] | [1-5][0-9]";
my $year      = "\\d{4}";
my $month     = "[0 ][1-9] | 1[012]";
my $day       = "[0 ][1-9] | [12][0-9] | 3[01]";
my $time_zone = qq{
        (?<time_zone>
              [A-Za-z]+
            | (?<offset_op>[+-]) (?<offset_hours>$hours)
            | (?<offset_op>[+-]) (?<offset_hours>$hours):?(?<offset_minutes>$minutes)
        )
};

my $am = langinfo( AM_STR() );
my $pm = langinfo( PM_STR() );

my %patterns = (
    a   => "(?<weekday> $weekday_name_re )",
    b   => "(?<month_name> $month_name_re )",
    H   => "(?<hours> $hours)",
    I   => "(?<hours> $hours_12)",
    M   => "(?<minutes> $minutes)",
    S   => "(?<seconds> $seconds)",
    d   => "(?<day> $day )",
    m   => "(?<month> $month)",
    Y   => "(?<year> $year)",
    t   => '\s+',
    z   => $time_zone,
    Z   => "${time_zone}?",
    R   => "(?<hours>$hours):(?<minutes>$minutes)",
    T   => "(?<hours>$hours):(?<minutes>$minutes):(?<seconds>$seconds)",
    F   => "(?<year>$year)-(?<month>$month)-(?<day>$day)",
    p   => "(?:(?<am> \Q$am\E ) | (?<pm> \Q$pm\E ))",
    y   => '(?<short_year> \d\d )',
    C   => '(?<century> \d\d )',
    '%' => '%',
);

my %likes =
  ( A => 'a', B => 'b', e => 'd', h => 'b', k => 'H', l => 'I', n => 't' );

for my $like ( keys %likes ) {
    $patterns{$like} = $patterns{ $likes{$like} };
}

$patterns{c} = compile( langinfo( D_T_FMT() ) );
$patterns{D} = compile('%m/%d/%y');
$patterns{r} = compile('%I:%M:%S %p');

my %cache;

sub compile {
    my ($format) = @_;
    if ( $cache{$format} ) {
        return $cache{$format};
    }
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
    return $cache{$format} = qr($re)x;
}

1;
