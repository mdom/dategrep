package Moo::Object;

use Moo::_strictures;

our %NO_BUILD;
our %NO_DEMOLISH;
our $BUILD_MAKER;
our $DEMOLISH_MAKER;

sub new {
  my $class = shift;
  unless (exists $NO_DEMOLISH{$class}) {
    unless ($NO_DEMOLISH{$class} = !$class->can('DEMOLISH')) {
      ($DEMOLISH_MAKER ||= do {
        require Method::Generate::DemolishAll;
        Method::Generate::DemolishAll->new
      })->generate_method($class);
    }
  }
  $NO_BUILD{$class} and
    return bless({}, $class);
  $NO_BUILD{$class} = !$class->can('BUILD') unless exists $NO_BUILD{$class};
  $NO_BUILD{$class}
    ? bless({}, $class)
    : do {
        my $proto = ref($_[0]) eq 'HASH' ? $_[0] : { @_ };
        bless({}, $class)->BUILDALL($proto);
      };
}

# Inlined into Method::Generate::Constructor::_generate_args() - keep in sync
sub BUILDARGS {
    my $class = shift;
    if ( scalar @_ == 1 ) {
        unless ( defined $_[0] && ref $_[0] eq 'HASH' ) {
            die "Single parameters to new() must be a HASH ref"
                ." data => ". $_[0] ."\n";
        }
        return { %{ $_[0] } };
    }
    elsif ( @_ % 2 ) {
        die "The new() method for $class expects a hash reference or a"
          . " key/value list. You passed an odd number of arguments\n";
    }
    else {
        return {@_};
    }
}

sub BUILDALL {
  my $self = shift;
  $self->${\(($BUILD_MAKER ||= do {
    require Method::Generate::BuildAll;
    Method::Generate::BuildAll->new
  })->generate_method(ref($self)))}(@_);
}

sub DEMOLISHALL {
  my $self = shift;
  $self->${\(($DEMOLISH_MAKER ||= do {
    require Method::Generate::DemolishAll;
    Method::Generate::DemolishAll->new
  })->generate_method(ref($self)))}(@_);
}

sub does {
  require Moo::Role;
  my $does = Moo::Role->can("does_role");
  { no warnings 'redefine'; *does = $does }
  goto &$does;
}

# duplicated in Moo::Role
sub meta {
  require Moo::HandleMoose::FakeMetaClass;
  my $class = ref($_[0])||$_[0];
  bless({ name => $class }, 'Moo::HandleMoose::FakeMetaClass');
}

1;
