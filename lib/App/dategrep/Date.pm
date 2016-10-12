package App::dategrep::Date;
use strict;
use warnings;
use parent 'Exporter';
use Date::Manip::Delta;
use Date::Manip::Date;

our @EXPORT_OK = qw(intervall_to_epoch date_to_epoch minutes_ago %formats);

our %formats = (
    'iso8601' => "%O%Z",
    'rsyslog' => "%b %e %H:%M:%S",
    'apache'  => "%d/%b/%Y:%T %z",
);

sub intervall_to_epoch {
    my ( $time, $format ) = @_;
    if ( $time =~ /^(.*) from (.*)$/ ) {
        my ( $delta, $date ) =
          ( Date::Manip::Delta->new($1), Date::Manip::Date->new($2) );
        ## TODO: $date->is_date is missing in Date::Manip::Date
        ## will be fixed in next major release
        if ( $delta->is_delta() ) {    ## and $date->is_date() ) {
            return $date->calc($delta)->secs_since_1970_GMT();
        }
    }
    return date_to_epoch( $time, $format );
}

sub minutes_ago {
    my $minutes = shift;
    my $now     = Date::Manip::Date->new("now");
    $now->set( 's', 0 );
    my $ago = Date::Manip::Date->new("$minutes minutes ago");
    $ago->set( 's', 0 );
    return ( $ago->secs_since_1970_GMT(), $now->secs_since_1970_GMT() );
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

1;
