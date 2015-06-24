package Method::Generate::Accessor;

use Moo::_strictures;
use Moo::_Utils;
use Moo::Object ();
our @ISA = qw(Moo::Object);
use Sub::Quote qw(quote_sub quoted_from_sub quotify);
use Scalar::Util 'blessed';
use overload ();
use Module::Runtime qw(use_module);
BEGIN {
  our $CAN_HAZ_XS =
    !$ENV{MOO_XS_DISABLE}
      &&
    _maybe_load_module('Class::XSAccessor')
      &&
    (eval { Class::XSAccessor->VERSION('1.07') })
  ;
  our $CAN_HAZ_XS_PRED =
    $CAN_HAZ_XS &&
    (eval { Class::XSAccessor->VERSION('1.17') })
  ;
}

my $module_name_only = qr/\A$Module::Runtime::module_name_rx\z/;

sub _die_overwrite
{
  my ($pkg, $method, $type) = @_;
  die "You cannot overwrite a locally defined method ($method) with "
    . ( $type || 'an accessor' );
}

sub generate_method {
  my ($self, $into, $name, $spec, $quote_opts) = @_;
  $spec->{allow_overwrite}++ if $name =~ s/^\+//;
  die "Must have an is" unless my $is = $spec->{is};
  if ($is eq 'ro') {
    $spec->{reader} = $name unless exists $spec->{reader};
  } elsif ($is eq 'rw') {
    $spec->{accessor} = $name unless exists $spec->{accessor}
      or ( $spec->{reader} and $spec->{writer} );
  } elsif ($is eq 'lazy') {
    $spec->{reader} = $name unless exists $spec->{reader};
    $spec->{lazy} = 1;
    $spec->{builder} ||= '_build_'.$name unless exists $spec->{default};
  } elsif ($is eq 'rwp') {
    $spec->{reader} = $name unless exists $spec->{reader};
    $spec->{writer} = "_set_${name}" unless exists $spec->{writer};
  } elsif ($is ne 'bare') {
    die "Unknown is ${is}";
  }
  if (exists $spec->{builder}) {
    if(ref $spec->{builder}) {
      $self->_validate_codulatable('builder', $spec->{builder},
        "$into->$name", 'or a method name');
      $spec->{builder_sub} = $spec->{builder};
      $spec->{builder} = 1;
    }
    $spec->{builder} = '_build_'.$name if ($spec->{builder}||0) eq 1;
    die "Invalid builder for $into->$name - not a valid method name"
      if $spec->{builder} !~ $module_name_only;
  }
  if (($spec->{predicate}||0) eq 1) {
    $spec->{predicate} = $name =~ /^_/ ? "_has${name}" : "has_${name}";
  }
  if (($spec->{clearer}||0) eq 1) {
    $spec->{clearer} = $name =~ /^_/ ? "_clear${name}" : "clear_${name}";
  }
  if (($spec->{trigger}||0) eq 1) {
    $spec->{trigger} = quote_sub('shift->_trigger_'.$name.'(@_)');
  }
  if (($spec->{coerce}||0) eq 1) {
    my $isa = $spec->{isa};
    if (blessed $isa and $isa->can('coercion')) {
      $spec->{coerce} = $isa->coercion;
    } elsif (blessed $isa and $isa->can('coerce')) {
      $spec->{coerce} = sub { $isa->coerce(@_) };
    } else {
      die "Invalid coercion for $into->$name - no appropriate type constraint";
    }
  }

  for my $setting (qw( isa coerce )) {
    next if !exists $spec->{$setting};
    $self->_validate_codulatable($setting, $spec->{$setting}, "$into->$name");
  }

  if (exists $spec->{default}) {
    if (ref $spec->{default}) {
      $self->_validate_codulatable('default', $spec->{default}, "$into->$name",
        'or a non-ref');
    }
  }

  if (exists $spec->{moosify}) {
    if (ref $spec->{moosify} ne 'ARRAY') {
      $spec->{moosify} = [$spec->{moosify}];
    }

    for my $spec (@{$spec->{moosify}}) {
      $self->_validate_codulatable('moosify', $spec, "$into->$name");
    }
  }

  my %methods;
  if (my $reader = $spec->{reader}) {
    _die_overwrite($into, $reader, 'a reader')
      if !$spec->{allow_overwrite} && *{_getglob("${into}::${reader}")}{CODE};
    if (our $CAN_HAZ_XS && $self->is_simple_get($name, $spec)) {
      $methods{$reader} = $self->_generate_xs(
        getters => $into, $reader, $name, $spec
      );
    } else {
      $self->{captures} = {};
      $methods{$reader} =
        quote_sub "${into}::${reader}"
          => '    die "'.$reader.' is a read-only accessor" if @_ > 1;'."\n"
             .$self->_generate_get($name, $spec)
          => delete $self->{captures}
        ;
    }
  }
  if (my $accessor = $spec->{accessor}) {
    _die_overwrite($into, $accessor, 'an accessor')
      if !$spec->{allow_overwrite} && *{_getglob("${into}::${accessor}")}{CODE};
    if (
      our $CAN_HAZ_XS
      && $self->is_simple_get($name, $spec)
      && $self->is_simple_set($name, $spec)
    ) {
      $methods{$accessor} = $self->_generate_xs(
        accessors => $into, $accessor, $name, $spec
      );
    } else {
      $self->{captures} = {};
      $methods{$accessor} =
        quote_sub "${into}::${accessor}"
          => $self->_generate_getset($name, $spec)
          => delete $self->{captures}
        ;
    }
  }
  if (my $writer = $spec->{writer}) {
    _die_overwrite($into, $writer, 'a writer')
      if !$spec->{allow_overwrite} && *{_getglob("${into}::${writer}")}{CODE};
    if (
      our $CAN_HAZ_XS
      && $self->is_simple_set($name, $spec)
    ) {
      $methods{$writer} = $self->_generate_xs(
        setters => $into, $writer, $name, $spec
      );
    } else {
      $self->{captures} = {};
      $methods{$writer} =
        quote_sub "${into}::${writer}"
          => $self->_generate_set($name, $spec)
          => delete $self->{captures}
        ;
    }
  }
  if (my $pred = $spec->{predicate}) {
    _die_overwrite($into, $pred, 'a predicate')
      if !$spec->{allow_overwrite} && *{_getglob("${into}::${pred}")}{CODE};
    if (our $CAN_HAZ_XS && our $CAN_HAZ_XS_PRED) {
      $methods{$pred} = $self->_generate_xs(
        exists_predicates => $into, $pred, $name, $spec
      );
    } else {
      $methods{$pred} =
        quote_sub "${into}::${pred}" =>
          '    '.$self->_generate_simple_has('$_[0]', $name, $spec)."\n"
        ;
    }
  }
  if (my $pred = $spec->{builder_sub}) {
    _install_coderef( "${into}::$spec->{builder}" => $spec->{builder_sub} );
  }
  if (my $cl = $spec->{clearer}) {
    _die_overwrite($into, $cl, 'a clearer')
      if !$spec->{allow_overwrite} && *{_getglob("${into}::${cl}")}{CODE};
    $methods{$cl} =
      quote_sub "${into}::${cl}" =>
        $self->_generate_simple_clear('$_[0]', $name, $spec)."\n"
      ;
  }
  if (my $hspec = $spec->{handles}) {
    my $asserter = $spec->{asserter} ||= '_assert_'.$name;
    my @specs = do {
      if (ref($hspec) eq 'ARRAY') {
        map [ $_ => $_ ], @$hspec;
      } elsif (ref($hspec) eq 'HASH') {
        map [ $_ => ref($hspec->{$_}) ? @{$hspec->{$_}} : $hspec->{$_} ],
          keys %$hspec;
      } elsif (!ref($hspec)) {
        map [ $_ => $_ ], use_module('Moo::Role')->methods_provided_by(use_module($hspec))
      } else {
        die "You gave me a handles of ${hspec} and I have no idea why";
      }
    };
    foreach my $delegation_spec (@specs) {
      my ($proxy, $target, @args) = @$delegation_spec;
      _die_overwrite($into, $proxy, 'a delegation')
        if !$spec->{allow_overwrite} && *{_getglob("${into}::${proxy}")}{CODE};
      $self->{captures} = {};
      $methods{$proxy} =
        quote_sub "${into}::${proxy}" =>
          $self->_generate_delegation($asserter, $target, \@args),
          delete $self->{captures}
        ;
    }
  }
  if (my $asserter = $spec->{asserter}) {
    $self->{captures} = {};


    $methods{$asserter} =
      quote_sub "${into}::${asserter}" =>
        $self->_generate_asserter($name, $spec),
        delete $self->{captures};
  }
  \%methods;
}

sub is_simple_attribute {
  my ($self, $name, $spec) = @_;
  # clearer doesn't have to be listed because it doesn't
  # affect whether defined/exists makes a difference
  !grep $spec->{$_},
    qw(lazy default builder coerce isa trigger predicate weak_ref);
}

sub is_simple_get {
  my ($self, $name, $spec) = @_;
  !($spec->{lazy} and (exists $spec->{default} or $spec->{builder}));
}

sub is_simple_set {
  my ($self, $name, $spec) = @_;
  !grep $spec->{$_}, qw(coerce isa trigger weak_ref);
}

sub has_eager_default {
  my ($self, $name, $spec) = @_;
  (!$spec->{lazy} and (exists $spec->{default} or $spec->{builder}));
}

sub _generate_get {
  my ($self, $name, $spec) = @_;
  my $simple = $self->_generate_simple_get('$_[0]', $name, $spec);
  if ($self->is_simple_get($name, $spec)) {
    $simple;
  } else {
    $self->_generate_use_default(
      '$_[0]', $name, $spec,
      $self->_generate_simple_has('$_[0]', $name, $spec),
    );
  }
}

sub generate_simple_has {
  my $self = shift;
  $self->{captures} = {};
  my $code = $self->_generate_simple_has(@_);
  ($code, delete $self->{captures});
}

sub _generate_simple_has {
  my ($self, $me, $name) = @_;
  "exists ${me}->{${\quotify $name}}";
}

sub _generate_simple_clear {
  my ($self, $me, $name) = @_;
  "    delete ${me}->{${\quotify $name}}\n"
}

sub generate_get_default {
  my $self = shift;
  $self->{captures} = {};
  my $code = $self->_generate_get_default(@_);
  ($code, delete $self->{captures});
}

sub generate_use_default {
  my $self = shift;
  $self->{captures} = {};
  my $code = $self->_generate_use_default(@_);
  ($code, delete $self->{captures});
}

sub _generate_use_default {
  my ($self, $me, $name, $spec, $test) = @_;
  my $get_value = $self->_generate_get_default($me, $name, $spec);
  if ($spec->{coerce}) {
    $get_value = $self->_generate_coerce(
      $name, $get_value,
      $spec->{coerce}
    )
  }
  $test." ? \n"
  .$self->_generate_simple_get($me, $name, $spec)."\n:"
  .($spec->{isa} ?
       "    do {\n      my \$value = ".$get_value.";\n"
      ."      ".$self->_generate_isa_check($name, '$value', $spec->{isa}).";\n"
      ."      ".$self->_generate_simple_set($me, $name, $spec, '$value')."\n"
      ."    }\n"
    : '    ('.$self->_generate_simple_set($me, $name, $spec, $get_value).")\n"
  );
}

sub _generate_get_default {
  my ($self, $me, $name, $spec) = @_;
  if (exists $spec->{default}) {
    ref $spec->{default}
      ? $self->_generate_call_code($name, 'default', $me, $spec->{default})
    : quotify $spec->{default};
  }
  else {
    "${me}->${\$spec->{builder}}"
  }
}

sub generate_simple_get {
  my ($self, @args) = @_;
  $self->{captures} = {};
  my $code = $self->_generate_simple_get(@args);
  ($code, delete $self->{captures});
}

sub _generate_simple_get {
  my ($self, $me, $name) = @_;
  my $name_str = quotify $name;
  "${me}->{${name_str}}";
}

sub _generate_set {
  my ($self, $name, $spec) = @_;
  if ($self->is_simple_set($name, $spec)) {
    $self->_generate_simple_set('$_[0]', $name, $spec, '$_[1]');
  } else {
    my ($coerce, $trigger, $isa_check) = @{$spec}{qw(coerce trigger isa)};
    my $value_store = '$_[0]';
    my $code;
    if ($coerce) {
      $value_store = '$value';
      $code = "do { my (\$self, \$value) = \@_;\n"
        ."        \$value = "
        .$self->_generate_coerce($name, $value_store, $coerce).";\n";
    }
    else {
      $code = "do { my \$self = shift;\n";
    }
    if ($isa_check) {
      $code .=
        "        ".$self->_generate_isa_check($name, $value_store, $isa_check).";\n";
    }
    my $simple = $self->_generate_simple_set('$self', $name, $spec, $value_store);
    if ($trigger) {
      my $fire = $self->_generate_trigger($name, '$self', $value_store, $trigger);
      $code .=
        "        ".$simple.";\n        ".$fire.";\n"
        ."        $value_store;\n";
    } else {
      $code .= "        ".$simple.";\n";
    }
    $code .= "      }";
    $code;
  }
}

sub generate_coerce {
  my $self = shift;
  $self->{captures} = {};
  my $code = $self->_generate_coerce(@_);
  ($code, delete $self->{captures});
}

sub _attr_desc {
  my ($name, $init_arg) = @_;
  return quotify($name) if !defined($init_arg) or $init_arg eq $name;
  return quotify($name).' (constructor argument: '.quotify($init_arg).')';
}

sub _generate_coerce {
  my ($self, $name, $value, $coerce, $init_arg) = @_;
  $self->_wrap_attr_exception(
    $name,
    "coercion",
    $init_arg,
    $self->_generate_call_code($name, 'coerce', "${value}", $coerce),
    1,
  );
}

sub generate_trigger {
  my $self = shift;
  $self->{captures} = {};
  my $code = $self->_generate_trigger(@_);
  ($code, delete $self->{captures});
}

sub _generate_trigger {
  my ($self, $name, $obj, $value, $trigger) = @_;
  $self->_generate_call_code($name, 'trigger', "${obj}, ${value}", $trigger);
}

sub generate_isa_check {
  my ($self, @args) = @_;
  $self->{captures} = {};
  my $code = $self->_generate_isa_check(@args);
  ($code, delete $self->{captures});
}

sub _wrap_attr_exception {
  my ($self, $name, $step, $arg, $code, $want_return) = @_;
  my $prefix = quotify("${step} for "._attr_desc($name, $arg).' failed: ');
  "do {\n"
  .'  local $Method::Generate::Accessor::CurrentAttribute = {'."\n"
  .'    init_arg => '.quotify($arg).",\n"
  .'    name     => '.quotify($name).",\n"
  .'    step     => '.quotify($step).",\n"
  ."  };\n"
  .($want_return ? '  my $_return;'."\n" : '')
  .'  my $_error;'."\n"
  ."  {\n"
  .'    my $_old_error = $@;'."\n"
  ."    if (!eval {\n"
  .'      $@ = $_old_error;'."\n"
  .($want_return ? '      $_return ='."\n" : '')
  .'      '.$code.";\n"
  ."      1;\n"
  ."    }) {\n"
  .'      $_error = $@;'."\n"
  .'      if (!ref $_error) {'."\n"
  .'        $_error = '.$prefix.'.$_error;'."\n"
  ."      }\n"
  ."    }\n"
  .'    $@ = $_old_error;'."\n"
  ."  }\n"
  .'  die $_error if $_error;'."\n"
  .($want_return ? '  $_return;'."\n" : '')
  ."}\n"
}

sub _generate_isa_check {
  my ($self, $name, $value, $check, $init_arg) = @_;
  $self->_wrap_attr_exception(
    $name,
    "isa check",
    $init_arg,
    $self->_generate_call_code($name, 'isa_check', $value, $check)
  );
}

sub _generate_call_code {
  my ($self, $name, $type, $values, $sub) = @_;
  $sub = \&{$sub} if blessed($sub);  # coderef if blessed
  if (my $quoted = quoted_from_sub($sub)) {
    my $local = 1;
    if ($values eq '@_' || $values eq '$_[0]') {
      $local = 0;
      $values = '@_';
    }
    my $code = $quoted->[1];
    if (my $captures = $quoted->[2]) {
      my $cap_name = qq{\$${type}_captures_for_}.$self->_sanitize_name($name);
      $self->{captures}->{$cap_name} = \$captures;
      Sub::Quote::inlinify($code, $values,
        Sub::Quote::capture_unroll($cap_name, $captures, 6), $local);
    } else {
      Sub::Quote::inlinify($code, $values, undef, $local);
    }
  } else {
    my $cap_name = qq{\$${type}_for_}.$self->_sanitize_name($name);
    $self->{captures}->{$cap_name} = \$sub;
    "${cap_name}->(${values})";
  }
}

sub _sanitize_name {
  my ($self, $name) = @_;
  $name =~ s/([_\W])/sprintf('_%x', ord($1))/ge;
  $name;
}

sub generate_populate_set {
  my $self = shift;
  $self->{captures} = {};
  my $code = $self->_generate_populate_set(@_);
  ($code, delete $self->{captures});
}

sub _generate_populate_set {
  my ($self, $me, $name, $spec, $source, $test, $init_arg) = @_;
  if ($self->has_eager_default($name, $spec)) {
    my $get_indent = ' ' x ($spec->{isa} ? 6 : 4);
    my $get_default = $self->_generate_get_default(
                        '$new', $name, $spec
                      );
    my $get_value =
      defined($spec->{init_arg})
        ? "(\n${get_indent}  ${test}\n"
            ."${get_indent}   ? ${source}\n${get_indent}   : "
            .$get_default
            ."\n${get_indent})"
        : $get_default;
    if ($spec->{coerce}) {
      $get_value = $self->_generate_coerce(
        $name, $get_value,
        $spec->{coerce}, $init_arg
      )
    }
    ($spec->{isa}
      ? "    {\n      my \$value = ".$get_value.";\n      "
        .$self->_generate_isa_check(
          $name, '$value', $spec->{isa}, $init_arg
        ).";\n"
        .'      '.$self->_generate_simple_set($me, $name, $spec, '$value').";\n"
        ."    }\n"
      : '    '.$self->_generate_simple_set($me, $name, $spec, $get_value).";\n"
    )
    .($spec->{trigger}
      ? '    '
        .$self->_generate_trigger(
          $name, $me, $self->_generate_simple_get($me, $name, $spec),
          $spec->{trigger}
        )." if ${test};\n"
      : ''
    );
  } else {
    "    if (${test}) {\n"
      .($spec->{coerce}
        ? "      $source = "
          .$self->_generate_coerce(
            $name, $source,
            $spec->{coerce}, $init_arg
          ).";\n"
        : ""
      )
      .($spec->{isa}
        ? "      "
          .$self->_generate_isa_check(
            $name, $source, $spec->{isa}, $init_arg
          ).";\n"
        : ""
      )
      ."      ".$self->_generate_simple_set($me, $name, $spec, $source).";\n"
      .($spec->{trigger}
        ? "      "
          .$self->_generate_trigger(
            $name, $me, $self->_generate_simple_get($me, $name, $spec),
            $spec->{trigger}
          ).";\n"
        : ""
      )
      ."    }\n";
  }
}

sub _generate_core_set {
  my ($self, $me, $name, $spec, $value) = @_;
  my $name_str = quotify $name;
  "${me}->{${name_str}} = ${value}";
}

sub _generate_simple_set {
  my ($self, $me, $name, $spec, $value) = @_;
  my $name_str = quotify $name;
  my $simple = $self->_generate_core_set($me, $name, $spec, $value);

  if ($spec->{weak_ref}) {
    require Scalar::Util;
    my $get = $self->_generate_simple_get($me, $name, $spec);

    # Perl < 5.8.3 can't weaken refs to readonly vars
    # (e.g. string constants). This *can* be solved by:
    #
    # &Internals::SvREADONLY($foo, 0);
    # Scalar::Util::weaken($foo);
    # &Internals::SvREADONLY($foo, 1);
    #
    # but requires Internal functions and is just too damn crazy
    # so simply throw a better exception
    my $weak_simple = "do { Scalar::Util::weaken(${simple}); no warnings 'void'; $get }";
    Moo::_Utils::lt_5_8_3() ? <<"EOC" : $weak_simple;
      eval { Scalar::Util::weaken($simple); 1 }
        ? do { no warnings 'void'; $get }
        : do {
          if( \$@ =~ /Modification of a read-only value attempted/) {
            require Carp;
            Carp::croak( sprintf (
              'Reference to readonly value in "%s" can not be weakened on Perl < 5.8.3',
              $name_str,
            ) );
          } else {
            die \$@;
          }
        }
EOC
  } else {
    $simple;
  }
}

sub _generate_getset {
  my ($self, $name, $spec) = @_;
  q{(@_ > 1}."\n      ? ".$self->_generate_set($name, $spec)
    ."\n      : ".$self->_generate_get($name, $spec)."\n    )";
}

sub _generate_asserter {
  my ($self, $name, $spec) = @_;

  "do {\n"
   ."  my \$val = ".$self->_generate_get($name, $spec).";\n"
   ."  unless (".$self->_generate_simple_has('$_[0]', $name, $spec).") {\n"
   .qq!    die "Attempted to access '${name}' but it is not set";\n!
   ."  }\n"
   ."  \$val;\n"
   ."}\n";
}
sub _generate_delegation {
  my ($self, $asserter, $target, $args) = @_;
  my $arg_string = do {
    if (@$args) {
      # I could, I reckon, linearise out non-refs here using quotify
      # plus something to check for numbers but I'm unsure if it's worth it
      $self->{captures}{'@curries'} = $args;
      '@curries, @_';
    } else {
      '@_';
    }
  };
  "shift->${asserter}->${target}(${arg_string});";
}

sub _generate_xs {
  my ($self, $type, $into, $name, $slot) = @_;
  Class::XSAccessor->import(
    class => $into,
    $type => { $name => $slot },
    replace => 1,
  );
  $into->can($name);
}

sub default_construction_string { '{}' }

sub _validate_codulatable {
  my ($self, $setting, $value, $into, $appended) = @_;
  my $invalid = "Invalid $setting '" . overload::StrVal($value)
    . "' for $into not a coderef";
  $invalid .= " $appended" if $appended;

  unless (ref $value and (ref $value eq 'CODE' or blessed($value))) {
    die "$invalid or code-convertible object";
  }

  unless (eval { \&$value }) {
    die "$invalid and could not be converted to a coderef: $@";
  }

  1;
}

1;
