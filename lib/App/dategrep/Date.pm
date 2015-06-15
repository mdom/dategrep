package App::dategrep::Date;
use strict;
use warnings;
use parent 'Exporter';
use Date::Manip::Delta;
use Date::Manip::Date;

our @EXPORT_OK = qw(intervall_to_epoch date_to_epoch);

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
