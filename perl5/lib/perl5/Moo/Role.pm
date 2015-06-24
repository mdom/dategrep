package Moo::Role;

use Moo::_strictures;
use Moo::_Utils;
use Role::Tiny ();
our @ISA = qw(Role::Tiny);

our $VERSION = '2.000001';
$VERSION = eval $VERSION;

require Moo::sification;

BEGIN {
    *INFO = \%Role::Tiny::INFO;
    *APPLIED_TO = \%Role::Tiny::APPLIED_TO;
    *ON_ROLE_CREATE = \@Role::Tiny::ON_ROLE_CREATE;
}

our %INFO;
our %APPLIED_TO;
our %APPLY_DEFAULTS;
our @ON_ROLE_CREATE;

sub _install_tracked {
  my ($target, $name, $code) = @_;
  $INFO{$target}{exports}{$name} = $code;
  _install_coderef "${target}::${name}" => "Moo::Role::${name}" => $code;
}

sub import {
  my $target = caller;
  my ($me) = @_;

  _set_loaded(caller);
  strict->import;
  warnings->import;
  if ($Moo::MAKERS{$target} and $Moo::MAKERS{$target}{is_class}) {
    die "Cannot import Moo::Role into a Moo class";
  }
  $INFO{$target} ||= {};
  # get symbol table reference
  my $stash = _getstash($target);
  _install_tracked $target => has => sub {
    my $name_proto = shift;
    my @name_proto = ref $name_proto eq 'ARRAY' ? @$name_proto : $name_proto;
    if (@_ % 2 != 0) {
      require Carp;
      Carp::croak("Invalid options for " . join(', ', map "'$_'", @name_proto)
        . " attribute(s): even number of arguments expected, got " . scalar @_)
    }
    my %spec = @_;
    foreach my $name (@name_proto) {
      my $spec_ref = @name_proto > 1 ? +{%spec} : \%spec;
      ($INFO{$target}{accessor_maker} ||= do {
        require Method::Generate::Accessor;
        Method::Generate::Accessor->new
      })->generate_method($target, $name, $spec_ref);
      push @{$INFO{$target}{attributes}||=[]}, $name, $spec_ref;
      $me->_maybe_reset_handlemoose($target);
    }
  };
  # install before/after/around subs
  foreach my $type (qw(before after around)) {
    _install_tracked $target => $type => sub {
      require Class::Method::Modifiers;
      push @{$INFO{$target}{modifiers}||=[]}, [ $type => @_ ];
      $me->_maybe_reset_handlemoose($target);
    };
  }
  _install_tracked $target => requires => sub {
    push @{$INFO{$target}{requires}||=[]}, @_;
    $me->_maybe_reset_handlemoose($target);
  };
  _install_tracked $target => with => sub {
    $me->apply_roles_to_package($target, @_);
    $me->_maybe_reset_handlemoose($target);
  };
  return if $me->is_role($target); # already exported into this package
  $INFO{$target}{is_role} = 1;
  *{_getglob("${target}::meta")} = $me->can('meta');
  # grab all *non-constant* (stash slot is not a scalarref) subs present
  # in the symbol table and store their refaddrs (no need to forcibly
  # inflate constant subs into real subs) - also add '' to here (this
  # is used later) with a map to the coderefs in case of copying or re-use
  my @not_methods = ('', map { *$_{CODE}||() } grep !ref($_), values %$stash);
  @{$INFO{$target}{not_methods}={}}{@not_methods} = @not_methods;
  # a role does itself
  $APPLIED_TO{$target} = { $target => undef };

  $_->($target)
    for @ON_ROLE_CREATE;
}

push @ON_ROLE_CREATE, sub {
  my $target = shift;
  if ($INC{'Moo/HandleMoose.pm'}) {
    Moo::HandleMoose::inject_fake_metaclass_for($target);
  }
};

# duplicate from Moo::Object
sub meta {
  require Moo::HandleMoose::FakeMetaClass;
  my $class = ref($_[0])||$_[0];
  bless({ name => $class }, 'Moo::HandleMoose::FakeMetaClass');
}

sub unimport {
  my $target = caller;
  _unimport_coderefs($target, $INFO{$target});
}

sub _maybe_reset_handlemoose {
  my ($class, $target) = @_;
  if ($INC{"Moo/HandleMoose.pm"}) {
    Moo::HandleMoose::maybe_reinject_fake_metaclass_for($target);
  }
}

sub methods_provided_by {
  my ($self, $role) = @_;
  _load_module($role);
  $self->_inhale_if_moose($role);
  die "${role} is not a Moo::Role" unless $self->is_role($role);
  return $self->SUPER::methods_provided_by($role);
}

sub is_role {
  my ($self, $role) = @_;
  $self->_inhale_if_moose($role);
  $self->SUPER::is_role($role);
}

sub _inhale_if_moose {
  my ($self, $role) = @_;
  my $meta;
  if (!$self->SUPER::is_role($role)
      and (
        $INC{"Moose.pm"}
        and $meta = Class::MOP::class_of($role)
        and ref $meta ne 'Moo::HandleMoose::FakeMetaClass'
        and $meta->isa('Moose::Meta::Role')
      )
      or (
        Mouse::Util->can('find_meta')
        and $meta = Mouse::Util::find_meta($role)
        and $meta->isa('Mouse::Meta::Role')
     )
  ) {
    my $is_mouse = $meta->isa('Mouse::Meta::Role');
    $INFO{$role}{methods} = {
      map +($_ => $role->can($_)),
        grep $role->can($_),
        grep !($is_mouse && $_ eq 'meta'),
        grep !$meta->get_method($_)->isa('Class::MOP::Method::Meta'),
          $meta->get_method_list
    };
    $APPLIED_TO{$role} = {
      map +($_->name => 1), $meta->calculate_all_roles
    };
    $INFO{$role}{requires} = [ $meta->get_required_method_list ];
    $INFO{$role}{attributes} = [
      map +($_ => do {
        my $attr = $meta->get_attribute($_);
        my $spec = { %{ $is_mouse ? $attr : $attr->original_options } };

        if ($spec->{isa}) {

          my $get_constraint = do {
            my $pkg = $is_mouse
                        ? 'Mouse::Util::TypeConstraints'
                        : 'Moose::Util::TypeConstraints';
            _load_module($pkg);
            $pkg->can('find_or_create_isa_type_constraint');
          };

          my $tc = $get_constraint->($spec->{isa});
          my $check = $tc->_compiled_type_constraint;

          $spec->{isa} = sub {
            &$check or die "Type constraint failed for $_[0]"
          };

          if ($spec->{coerce}) {

             # Mouse has _compiled_type_coercion straight on the TC object
             $spec->{coerce} = $tc->${\(
               $tc->can('coercion')||sub { $_[0] }
             )}->_compiled_type_coercion;
          }
        }
        $spec;
      }), $meta->get_attribute_list
    ];
    my $mods = $INFO{$role}{modifiers} = [];
    foreach my $type (qw(before after around)) {
      # Mouse pokes its own internals so we have to fall back to doing
      # the same thing in the absence of the Moose API method
      my $map = $meta->${\(
        $meta->can("get_${type}_method_modifiers_map")
        or sub { shift->{"${type}_method_modifiers"} }
      )};
      foreach my $method (keys %$map) {
        foreach my $mod (@{$map->{$method}}) {
          push @$mods, [ $type => $method => $mod ];
        }
      }
    }
    require Class::Method::Modifiers if @$mods;
    $INFO{$role}{inhaled_from_moose} = 1;
    $INFO{$role}{is_role} = 1;
  }
}

sub _maybe_make_accessors {
  my ($self, $target, $role) = @_;
  my $m;
  if ($INFO{$role} && $INFO{$role}{inhaled_from_moose}
      or $INC{"Moo.pm"}
      and $m = Moo->_accessor_maker_for($target)
      and ref($m) ne 'Method::Generate::Accessor') {
    $self->_make_accessors($target, $role);
  }
}

sub _make_accessors_if_moose {
  my ($self, $target, $role) = @_;
  if ($INFO{$role} && $INFO{$role}{inhaled_from_moose}) {
    $self->_make_accessors($target, $role);
  }
}

sub _make_accessors {
  my ($self, $target, $role) = @_;
  my $acc_gen = ($Moo::MAKERS{$target}{accessor} ||= do {
    require Method::Generate::Accessor;
    Method::Generate::Accessor->new
  });
  my $con_gen = $Moo::MAKERS{$target}{constructor};
  my @attrs = @{$INFO{$role}{attributes}||[]};
  while (my ($name, $spec) = splice @attrs, 0, 2) {
    # needed to ensure we got an index for an arrayref based generator
    if ($con_gen) {
      $spec = $con_gen->all_attribute_specs->{$name};
    }
    $acc_gen->generate_method($target, $name, $spec);
  }
}

sub role_application_steps {
  qw(_handle_constructor _maybe_make_accessors),
    $_[0]->SUPER::role_application_steps;
}

sub apply_roles_to_package {
  my ($me, $to, @roles) = @_;
  foreach my $role (@roles) {
    _load_module($role);
    $me->_inhale_if_moose($role);
    die "${role} is not a Moo::Role" unless $me->is_role($role);
  }
  $me->SUPER::apply_roles_to_package($to, @roles);
}

sub apply_single_role_to_package {
  my ($me, $to, $role) = @_;
  _load_module($role);
  $me->_inhale_if_moose($role);
  die "${role} is not a Moo::Role" unless $me->is_role($role);
  $me->SUPER::apply_single_role_to_package($to, $role);
}

sub create_class_with_roles {
  my ($me, $superclass, @roles) = @_;

  my ($new_name, $compose_name) = $me->_composite_name($superclass, @roles);

  return $new_name if $Role::Tiny::COMPOSED{class}{$new_name};

  foreach my $role (@roles) {
      _load_module($role);
      $me->_inhale_if_moose($role);
  }

  my $m;
  if ($INC{"Moo.pm"}
      and $m = Moo->_accessor_maker_for($superclass)
      and ref($m) ne 'Method::Generate::Accessor') {
    # old fashioned way time.
    *{_getglob("${new_name}::ISA")} = [ $superclass ];
    $Moo::MAKERS{$new_name} = {is_class => 1};
    $me->apply_roles_to_package($new_name, @roles);
    _set_loaded($new_name, (caller)[1]);
    return $new_name;
  }

  $me->SUPER::create_class_with_roles($superclass, @roles);

  foreach my $role (@roles) {
    die "${role} is not a Moo::Role" unless $me->is_role($role);
  }

  $Moo::MAKERS{$new_name} = {is_class => 1};

  $me->_handle_constructor($new_name, $_) for @roles;

  _set_loaded($new_name, (caller)[1]);
  return $new_name;
}

sub apply_roles_to_object {
  my ($me, $object, @roles) = @_;
  my $new = $me->SUPER::apply_roles_to_object($object, @roles);
  _set_loaded(ref $new, (caller)[1]);

  my $apply_defaults = $APPLY_DEFAULTS{ref $new} ||= do {
    my %attrs = map { @{$INFO{$_}{attributes}||[]} } @roles;

    if ($INC{'Moo.pm'}
        and keys %attrs
        and my $con_gen = Moo->_constructor_maker_for(ref $new)
        and my $m = Moo->_accessor_maker_for(ref $new)) {
      require Sub::Quote;

      my $specs = $con_gen->all_attribute_specs;

      my $assign = "{no warnings 'void';\n";
      my %captures;
      foreach my $name ( keys %attrs ) {
        my $spec = $specs->{$name};
        if ($m->has_eager_default($name, $spec)) {
          my ($has, $has_cap)
            = $m->generate_simple_has('$_[0]', $name, $spec);
          my ($code, $pop_cap)
            = $m->generate_use_default('$_[0]', $name, $spec, $has);

          $assign .= $code . ";\n";
          @captures{keys %$has_cap, keys %$pop_cap}
            = (values %$has_cap, values %$pop_cap);
        }
      }
      $assign .= "}";
      Sub::Quote::quote_sub($assign, \%captures);
    }
    else {
      sub {};
    }
  };
  $new->$apply_defaults;
  return $new;
}

sub _composable_package_for {
  my ($self, $role) = @_;
  my $composed_name = 'Role::Tiny::_COMPOSABLE::'.$role;
  return $composed_name if $Role::Tiny::COMPOSED{role}{$composed_name};
  $self->_make_accessors_if_moose($composed_name, $role);
  $self->SUPER::_composable_package_for($role);
}

sub _install_single_modifier {
  my ($me, @args) = @_;
  _install_modifier(@args);
}

sub _install_does {
    my ($me, $to) = @_;

    # If Role::Tiny actually installed the DOES, give it a name
    my $new = $me->SUPER::_install_does($to) or return;
    return _name_coderef("${to}::DOES", $new);
}

sub does_role {
  my ($proto, $role) = @_;
  return 1
    if Role::Tiny::does_role($proto, $role);
  my $meta;
  if ($INC{'Moose.pm'}
      and $meta = Class::MOP::class_of($proto)
      and ref $meta ne 'Moo::HandleMoose::FakeMetaClass'
  ) {
    return $meta->does_role($role);
  }
  return 0;
}

sub _handle_constructor {
  my ($me, $to, $role) = @_;
  my $attr_info = $INFO{$role} && $INFO{$role}{attributes};
  return unless $attr_info && @$attr_info;
  my $info = $INFO{$to};
  my $con = $INC{"Moo.pm"} && Moo->_constructor_maker_for($to);
  my %existing
    = $info ? @{$info->{attributes} || []}
    : $con  ? %{$con->all_attribute_specs || {}}
    : ();

  my @attr_info =
    map { @{$attr_info}[$_, $_+1] }
    grep { ! $existing{$attr_info->[$_]} }
    map { 2 * $_ } 0..@$attr_info/2-1;

  if ($info) {
    push @{$info->{attributes}||=[]}, @attr_info;
  }
  elsif ($con) {
    # shallow copy of the specs since the constructor will assign an index
    $con->register_attribute_specs(map ref() ? { %$_ } : $_, @attr_info);
  }
}

1;
__END__

=head1 NAME

Moo::Role - Minimal Object Orientation support for Roles

=head1 SYNOPSIS

 package My::Role;

 use Moo::Role;
 use strictures 2;

 sub foo { ... }

 sub bar { ... }

 has baz => (
   is => 'ro',
 );

 1;

And elsewhere:

 package Some::Class;

 use Moo;
 use strictures 2;

 # bar gets imported, but not foo
 with('My::Role');

 sub foo { ... }

 1;

=head1 DESCRIPTION

C<Moo::Role> builds upon L<Role::Tiny>, so look there for most of the
documentation on how this works.  The main addition here is extra bits to make
the roles more "Moosey;" which is to say, it adds L</has>.

=head1 IMPORTED SUBROUTINES

See L<Role::Tiny/IMPORTED SUBROUTINES> for all the other subroutines that are
imported by this module.

=head2 has

 has attr => (
   is => 'ro',
 );

Declares an attribute for the class to be composed into.  See
L<Moo/has> for all options.

=head1 CLEANING UP IMPORTS

L<Moo::Role> cleans up its own imported methods and any imports
declared before the C<use Moo::Role> statement automatically.
Anything imported after C<use Moo::Role> will be composed into
consuming packages.  A package that consumes this role:

 package My::Role::ID;

 use Digest::MD5 qw(md5_hex);
 use Moo::Role;
 use Digest::SHA qw(sha1_hex);

 requires 'name';

 sub as_md5  { my ($self) = @_; return md5_hex($self->name);  }
 sub as_sha1 { my ($self) = @_; return sha1_hex($self->name); }

 1;

..will now have a C<< $self->sha1_hex() >> method available to it
that probably does not do what you expect.  On the other hand, a call
to C<< $self->md5_hex() >> will die with the helpful error message:
C<Can't locate object method "md5_hex">.

See L<Moo/"CLEANING UP IMPORTS"> for more details.

=head1 SUPPORT

See L<Moo> for support and contact information.

=head1 AUTHORS

See L<Moo> for authors.

=head1 COPYRIGHT AND LICENSE

See L<Moo> for the copyright and license.

=cut
