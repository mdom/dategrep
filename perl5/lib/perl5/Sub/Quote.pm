package Sub::Quote;

sub _clean_eval { eval $_[0] }

use Moo::_strictures;

use Sub::Defer qw(defer_sub);
use Scalar::Util qw(weaken);
use Exporter qw(import);
use B ();
BEGIN {
  *_HAVE_PERLSTRING = defined &B::perlstring ? sub(){1} : sub(){0};
}

our $VERSION = '2.000001';
$VERSION = eval $VERSION;

our @EXPORT = qw(quote_sub unquote_sub quoted_from_sub qsub);
our @EXPORT_OK = qw(quotify capture_unroll inlinify);

our %QUOTED;

sub quotify {
  ! defined $_[0]     ? 'undef()'
  : _HAVE_PERLSTRING  ? B::perlstring($_[0])
  : qq["\Q$_[0]\E"];
}

sub capture_unroll {
  my ($from, $captures, $indent) = @_;
  join(
    '',
    map {
      /^([\@\%\$])/
        or die "capture key should start with \@, \% or \$: $_";
      (' ' x $indent).qq{my ${_} = ${1}{${from}->{${\quotify $_}}};\n};
    } keys %$captures
  );
}

sub inlinify {
  my ($code, $args, $extra, $local) = @_;
  my $do = 'do { '.($extra||'');
  if ($code =~ s/^(\s*package\s+([a-zA-Z0-9:]+);)//) {
    $do .= $1;
  }
  if ($code =~ s{
    \A((?:\#\ BEGIN\ quote_sub\ PRELUDE\n.*?\#\ END\ quote_sub\ PRELUDE\n)?\s*)
    (^\s*) my \s* \(([^)]+)\) \s* = \s* \@_;
  }{}xms) {
    my ($pre, $indent, $code_args) = ($1, $2, $3);
    $do .= $pre;
    if ($code_args ne $args) {
      $do .= $indent . 'my ('.$code_args.') = ('.$args.'); ';
    }
  }
  elsif ($local || $args ne '@_') {
    $do .= ($local ? 'local ' : '').'@_ = ('.$args.'); ';
  }
  $do.$code.' }';
}

sub quote_sub {
  # HOLY DWIMMERY, BATMAN!
  # $name => $code => \%captures => \%options
  # $name => $code => \%captures
  # $name => $code
  # $code => \%captures => \%options
  # $code
  my $options =
    (ref($_[-1]) eq 'HASH' and ref($_[-2]) eq 'HASH')
      ? pop
      : {};
  my $captures = ref($_[-1]) eq 'HASH' ? pop : undef;
  undef($captures) if $captures && !keys %$captures;
  my $code = pop;
  my $name = $_[0];
  my ($package, $hints, $bitmask, $hintshash) = (caller(0))[0,8,9,10];
  my $context
    ="# BEGIN quote_sub PRELUDE\n"
    ."package $package;\n"
    ."BEGIN {\n"
    ."  \$^H = ".quotify($hints).";\n"
    ."  \${^WARNING_BITS} = ".quotify($bitmask).";\n"
    ."  \%^H = (\n"
    . join('', map
     "    ".quotify($_)." => ".quotify($hintshash->{$_}).",",
      keys %$hintshash)
    ."  );\n"
    ."}\n"
    ."# END quote_sub PRELUDE\n";
  $code = "$context$code";
  my $quoted_info;
  my $unquoted;
  my $deferred = defer_sub +($options->{no_install} ? undef : $name) => sub {
    $unquoted if 0;
    unquote_sub($quoted_info->[4]);
  };
  $quoted_info = [ $name, $code, $captures, \$unquoted, $deferred ];
  weaken($quoted_info->[3]);
  weaken($quoted_info->[4]);
  weaken($QUOTED{$deferred} = $quoted_info);
  return $deferred;
}

sub quoted_from_sub {
  my ($sub) = @_;
  my $quoted_info = $QUOTED{$sub||''} or return undef;
  my ($name, $code, $captured, $unquoted, $deferred) = @{$quoted_info};
  $unquoted &&= $$unquoted;
  if (($deferred && $deferred eq $sub)
      || ($unquoted && $unquoted eq $sub)) {
    return [ $name, $code, $captured, $unquoted, $deferred ];
  }
  return undef;
}

sub unquote_sub {
  my ($sub) = @_;
  my $quoted = $QUOTED{$sub} or return undef;
  my $unquoted = $quoted->[3];
  unless ($unquoted && $$unquoted) {
    my ($name, $code, $captures) = @$quoted;

    my $make_sub = "{\n";

    my %captures = $captures ? %$captures : ();
    $captures{'$_UNQUOTED'} = \$unquoted;
    $captures{'$_QUOTED'} = \$quoted;
    $make_sub .= capture_unroll("\$_[1]", \%captures, 2);

    $make_sub .= (
      $name
          # disable the 'variable $x will not stay shared' warning since
          # we're not letting it escape from this scope anyway so there's
          # nothing trying to share it
        ? "  no warnings 'closure';\n  sub ${name} {\n"
        : "  \$\$_UNQUOTED = sub {\n"
    );
    $make_sub .= "  \$_QUOTED if 0;\n";
    $make_sub .= "  \$_UNQUOTED if 0;\n";
    $make_sub .= $code;
    $make_sub .= "  }".($name ? '' : ';')."\n";
    if ($name) {
      $make_sub .= "  \$\$_UNQUOTED = \\&${name}\n";
    }
    $make_sub .= "}\n1;\n";
    $ENV{SUB_QUOTE_DEBUG} && warn $make_sub;
    {
      no strict 'refs';
      local *{$name} if $name;
      my ($success, $e);
      {
        local $@;
        $success = _clean_eval($make_sub, \%captures);
        $e = $@;
      }
      unless ($success) {
        die "Eval went very, very wrong:\n\n${make_sub}\n\n$e";
      }
      weaken($QUOTED{$$unquoted} = $quoted);
    }
  }
  $$unquoted;
}

sub qsub ($) {
  goto &quote_sub;
}

sub CLONE {
  %QUOTED = map { defined $_ ? (
    $_->[3] && ${$_->[3]} ? (${ $_->[3] } => $_) : (),
    $_->[4] ? ($_->[4] => $_) : (),
  ) : () } values %QUOTED;
  weaken($_) for values %QUOTED;
}

1;
__END__

=head1 NAME

Sub::Quote - efficient generation of subroutines via string eval

=head1 SYNOPSIS

 package Silly;

 use Sub::Quote qw(quote_sub unquote_sub quoted_from_sub);

 quote_sub 'Silly::kitty', q{ print "meow" };

 quote_sub 'Silly::doggy', q{ print "woof" };

 my $sound = 0;

 quote_sub 'Silly::dagron',
   q{ print ++$sound % 2 ? 'burninate' : 'roar' },
   { '$sound' => \$sound };

And elsewhere:

 Silly->kitty;  # meow
 Silly->doggy;  # woof
 Silly->dagron; # burninate
 Silly->dagron; # roar
 Silly->dagron; # burninate

=head1 DESCRIPTION

This package provides performant ways to generate subroutines from strings.

=head1 SUBROUTINES

=head2 quote_sub

 my $coderef = quote_sub 'Foo::bar', q{ print $x++ . "\n" }, { '$x' => \0 };

Arguments: ?$name, $code, ?\%captures, ?\%options

C<$name> is the subroutine where the coderef will be installed.

C<$code> is a string that will be turned into code.

C<\%captures> is a hashref of variables that will be made available to the
code.  The keys should be the full name of the variable to be made available,
including the sigil.  The values should be references to the values.  The
variables will contain copies of the values.  See the L</SYNOPSIS>'s
C<Silly::dagron> for an example using captures.

=head3 options

=over 2

=item * no_install

B<Boolean>.  Set this option to not install the generated coderef into the
passed subroutine name on undefer.

=back

=head2 unquote_sub

 my $coderef = unquote_sub $sub;

Forcibly replace subroutine with actual code.

If $sub is not a quoted sub, this is a no-op.

=head2 quoted_from_sub

 my $data = quoted_from_sub $sub;

 my ($name, $code, $captures, $compiled_sub) = @$data;

Returns original arguments to quote_sub, plus the compiled version if this
sub has already been unquoted.

Note that $sub can be either the original quoted version or the compiled
version for convenience.

=head2 inlinify

 my $prelude = capture_unroll '$captures', {
   '$x' => 1,
   '$y' => 2,
 }, 4;

 my $inlined_code = inlinify q{
   my ($x, $y) = @_;

   print $x + $y . "\n";
 }, '$x, $y', $prelude;

Takes a string of code, a string of arguments, a string of code which acts as a
"prelude", and a B<Boolean> representing whether or not to localize the
arguments.

=head2 quotify

 my $quoted_value = quotify $value;

Quotes a single (non-reference) scalar value for use in a code string.  Numbers
aren't treated specially and will be quoted as strings, but undef will quoted as
C<undef()>.

=head2 capture_unroll

 my $prelude = capture_unroll '$captures', {
   '$x' => 1,
   '$y' => 2,
 }, 4;

Arguments: $from, \%captures, $indent

Generates a snippet of code which is suitable to be used as a prelude for
L</inlinify>.  C<$from> is a string will be used as a hashref in the resulting
code.  The keys of C<%captures> are the names of the variables and the values
are ignored.  C<$indent> is the number of spaces to indent the result by.

=head2 qsub

 my $hash = {
  coderef => qsub q{ print "hello"; },
  other   => 5,
 };

Arguments: $code

Works exactly like L</quote_sub>, but includes a prototype to only accept a
single parameter.  This makes it easier to include in hash structures or lists.

=head1 CAVEATS

Much of this is just string-based code-generation, and as a result, a few
caveats apply.

=head2 return

Calling C<return> from a quote_sub'ed sub will not likely do what you intend.
Instead of returning from the code you defined in C<quote_sub>, it will return
from the overall function it is composited into.

So when you pass in:

   quote_sub q{  return 1 if $condition; $morecode }

It might turn up in the intended context as follows:

  sub foo {

    <important code a>
    do {
      return 1 if $condition;
      $morecode
    };
    <important code b>

  }

Which will obviously return from foo, when all you meant to do was return from
the code context in quote_sub and proceed with running important code b.

=head2 pragmas

C<Sub::Quote> preserves the environment of the code creating the
quoted subs.  This includes the package, strict, warnings, and any
other lexical pragmas.  This is done by prefixing the code with a
block that sets up a matching environment.  When inlining C<Sub::Quote>
subs, care should be taken that user pragmas won't effect the rest
of the code.

=head1 SUPPORT

See L<Moo> for support and contact information.

=head1 AUTHORS

See L<Moo> for authors.

=head1 COPYRIGHT AND LICENSE

See L<Moo> for the copyright and license.

=cut
