package StrptimePP;
use strict;
use warnings;
use parent 'Exporter';
use Time::Local 'timelocal';
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
        return timelocal(
            $match{seconds} || 0,
            $match{minutes} || 0,
            $match{hours}   || 0,
            $match{day}     || $now[3],
            $match{month}   || $now[4],
            $match{year}    || $now[5],
        );
    }
    return;
}

my %patterns = (
    '%' => '%',
    H   => '(?<hours>(?:[01][0-9])|(?:2[0-3]))',
    M   => '(?<minutes>[0-5][0-9])',
    S   => '(?<seconds>[0-5][0-9])',

    d => '(?<day> 0[1-9] | [12][0-9] | 3[01] )',

    m => '(?<month>(?:0[1-9])|(?:1[012]))',
    Y => '(?<year>\d{4})',
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
