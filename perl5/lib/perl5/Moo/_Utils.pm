package Moo::_Utils;

no warnings 'once'; # guard against -w

sub _getglob { \*{$_[0]} }
sub _getstash { \%{"$_[0]::"} }

use constant lt_5_8_3 => ( $] < 5.008003 or $ENV{MOO_TEST_PRE_583} ) ? 1 : 0;
use constant can_haz_subutil => $INC{"Sub/Util.pm"}
    || ( !$INC{"Sub/Name.pm"} && eval { require Sub::Util } );
use constant can_haz_subname => $INC{"Sub/Name.pm"}
    || ( !$INC{"Sub/Util.pm"} && eval { require Sub::Name } );

use Moo::_strictures;
use Module::Runtime qw(use_package_optimistically module_notional_filename);

use Devel::GlobalDestruction ();
use Exporter qw(import);
use Moo::_mro;
use Config;

our @EXPORT = qw(
    _getglob _install_modifier _load_module _maybe_load_module
    _get_linear_isa _getstash _install_coderef _name_coderef
    _unimport_coderefs _in_global_destruction _set_loaded
);

sub _in_global_destruction ();
*_in_global_destruction = \&Devel::GlobalDestruction::in_global_destruction;

sub _install_modifier {
  my ($into, $type, $name, $code) = @_;

  if (my $to_modify = $into->can($name)) { # CMM will throw for us if not
    require Sub::Defer;
    Sub::Defer::undefer_sub($to_modify);
  }

  Class::Method::Modifiers::install_modifier(@_);
}

our %MAYBE_LOADED;

sub _load_module {
  my $module = $_[0];
  my $file = module_notional_filename($module);
  use_package_optimistically($module);
  return 1
    if $INC{$file};
  my $error = $@ || "Can't locate $file";

  # can't just ->can('can') because a sub-package Foo::Bar::Baz
  # creates a 'Baz::' key in Foo::Bar's symbol table
  my $stash = _getstash($module)||{};
  return 1 if grep +(!ref($_) and *$_{CODE}), values %$stash;
  return 1
    if $INC{"Moose.pm"} && Class::MOP::class_of($module)
    or Mouse::Util->can('find_meta') && Mouse::Util::find_meta($module);
  die $error;
}

sub _maybe_load_module {
  my $module = $_[0];
  return $MAYBE_LOADED{$module}
    if exists $MAYBE_LOADED{$module};
  if(! eval { use_package_optimistically($module) }) {
    warn "$module exists but failed to load with error: $@";
  }
  elsif ( $INC{module_notional_filename($module)} ) {
    return $MAYBE_LOADED{$module} = 1;
  }
  return $MAYBE_LOADED{$module} = 0;
}

sub _set_loaded {
  $INC{Module::Runtime::module_notional_filename($_[0])} ||= $_[1];
}

sub _get_linear_isa {
  return mro::get_linear_isa($_[0]);
}

sub _install_coderef {
  my ($glob, $code) = (_getglob($_[0]), _name_coderef(@_));
  no warnings 'redefine';
  if (*{$glob}{CODE}) {
    *{$glob} = $code;
  }
  # perl will sometimes warn about mismatched prototypes coming from the
  # inheritance cache, so disable them if we aren't redefining a sub
  else {
    no warnings 'prototype';
    *{$glob} = $code;
  }
}

sub _name_coderef {
  shift if @_ > 2; # three args is (target, name, sub)
  can_haz_subutil ? Sub::Util::set_subname(@_) :
    can_haz_subname ? Sub::Name::subname(@_) : $_[1];
}

sub _unimport_coderefs {
  my ($target, $info) = @_;
  return unless $info and my $exports = $info->{exports};
  my %rev = reverse %$exports;
  my $stash = _getstash($target);
  foreach my $name (keys %$exports) {
    if ($stash->{$name} and defined(&{$stash->{$name}})) {
      if ($rev{$target->can($name)}) {
        my $old = delete $stash->{$name};
        my $full_name = join('::',$target,$name);
        # Copy everything except the code slot back into place (e.g. $has)
        foreach my $type (qw(SCALAR HASH ARRAY IO)) {
          next unless defined(*{$old}{$type});
          no strict 'refs';
          *$full_name = *{$old}{$type};
        }
      }
    }
  }
}

if ($Config{useithreads}) {
  require Moo::HandleMoose::_TypeMap;
}

1;
