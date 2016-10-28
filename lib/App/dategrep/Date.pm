package App::dategrep::Date;
use Moo;
use Date::Manip::Delta;
use Date::Manip::Date;

has _formats => (
    is      => 'rw',
    default => sub {
        [
            "%O%Z",              # iso8601
            "%b %e %H:%M:%S",    # rsyslog
            "%d/%b/%Y:%T %z",    # apache
        ];
    },
);

has _date_object => ( is => 'rw', default => sub { Date::Manip::Date->new } );

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
    return $self->to_epoch($time);
}

sub minutes_ago {
    my ( $self, $minutes ) = (@_);
    my $now = Date::Manip::Date->new("now");
    $now->set( 's', 0 );
    my $ago = Date::Manip::Date->new("$minutes minutes ago");
    $ago->set( 's', 0 );
    return ( $ago->secs_since_1970_GMT, $now->secs_since_1970_GMT );
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
    my ( $self, $str, $format ) = @_;

    if ( !$format ) {
        $format = $self->guess_format($str);
    }

    my $error;
    if ($format) {
        $error = $self->_date_object->parse_format( $format, $str );
    }

    if ( !$format or $error ) {
        $error = $self->_date_object->parse($str);
    }

    return ( undef, $self->_date_object->err ) if $error;
    return ( $self->_date_object->secs_since_1970_GMT );
}

1;
