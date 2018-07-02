package App::dategrep::Date;
use Moo;
use Date::Manip::Delta;
use Date::Manip::Date;

has _formats => (
    is      => 'rw',
    default => sub {
        [
            '%b %e %H:%M:%S',                      # rsyslog
            '%d/%b/%Y:%T %z',                      # apache
            '%Y-%m-%d([T ])%H:%M:%S%Z',            # iso8601
            '%Y-%m-%d([T_])%H:%M:%S(\\.\\d+)?',    # svlogd -tt
        ];
    },
);

has _date_object => ( is => 'rw', default => sub { Date::Manip::Date->new } );
has now => ( is => 'rw', default => sub { Date::Manip::Date->new("now") } );

sub add_format {
    my $self    = shift;
    my %formats = map { $_ => 1 } @{ $self->_formats };
    my @new     = grep { !$formats{$_} } @_;
    unshift @{ $self->_formats }, @new;
}

sub formats {
    @{ shift->_formats };
}

sub intervall_to_epoch {
    my ( $self, $time ) = @_;
    if ( $time =~ /^(.*) from (.*)$/ ) {
        my ( $delta, $date ) =
          ( Date::Manip::Delta->new($1), Date::Manip::Date->new($2) );
        ## TODO: $date->is_date is missing in Date::Manip::Date
        ## will be fixed in next major release
        if ( $delta->is_delta ) {    ## and $date->is_date ) {
            return $date->calc($delta)->secs_since_1970_GMT;
        }
    }

    # First try our internal formats
    my ($date) = $self->to_epoch($time);
    return $date if $date;

    # Then check if Date::Manip can guess
    $date = Date::Manip::Date->new($time);
    if ( $date->err ) {
        return ( undef, $date->err );
    }
    return $date->secs_since_1970_GMT;
}

sub minutes_ago {
    my ( $self, $minutes ) = @_;
    my $to = $self->now;
    $to -= $to % 60;
    my $from = $to - $minutes * 60;
    return ($from, $to);
}

sub guess_format {
    my ( $self, $line ) = @_;
    for my $format ( $self->formats ) {
        my ($date) = $self->to_epoch( $line, $format );
        return $format if $date;
    }
    return;
}

sub to_epoch {
    my ( $self, $str, $format, %options ) = @_;

    $format ||= $self->guess_format($str);

    if ( !$format ) {
        return ( undef, "No date found in line $str" );
    }

    my ( $error, %match ) = $self->_date_object->parse_format( $format, $str );
    if ($error) {
        return ( undef, $self->_date_object->err );
    }

    ## check if date is in future
    if ( $self->_date_object->cmp( $self->now ) == 1 && $options{prefer_past} )
    {
        if ( !exists $match{y} ) {
            my $delta = Date::Manip::Delta->new('-1y');
            $self->_date_object( $self->_date_object->calc($delta) );
        }
    }

    return ( $self->_date_object->secs_since_1970_GMT );
}

1;
