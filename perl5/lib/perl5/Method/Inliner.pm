package Method::Inliner;

use Moo::_strictures;
use Text::Balanced qw(extract_bracketed);
use Sub::Quote ();

sub slurp { do { local (@ARGV, $/) = $_[0]; <> } }
sub splat {
  open my $out, '>', $_[1] or die "can't open $_[1]: $!";
  print $out $_[0] or die "couldn't write to $_[1]: $!";
}

sub inlinify {
  my $file = $_[0];
  my @chunks = split /(^sub.*?^}$)/sm, slurp $file;
  warn join "\n--\n", @chunks;
  my %code;
  foreach my $chunk (@chunks) {
    if (my ($name, $body) =
      $chunk =~ /^sub (\S+) {\n(.*)\n}$/s
    ) {
      $code{$name} = $body;
    }
  }
  foreach my $chunk (@chunks) {
    my ($me) = $chunk =~ /^sub.*{\n  my \((\$\w+).*\) = \@_;\n/ or next;
    my $meq = quotemeta $me;
    #warn $meq, $chunk;
    my $copy = $chunk;
    my ($fixed, $rest);
    while ($copy =~ s/^(.*?)${meq}->(\S+)(?=\()//s) {
      my ($front, $name) = ($1, $2);
      ((my $body), $rest) = extract_bracketed($copy, '()');
      warn "spotted ${name} - ${body}";
      if ($code{$name}) {
      warn "replacing";
        s/^\(//, s/\)$// for $body;
        $body = "${me}, ".$body;
        $fixed .= $front.Sub::Quote::inlinify($code{$name}, $body);
      } else {
        $fixed .= $front.$me.'->'.$name.$body;
      }
      #warn $fixed; warn $rest;
      $copy = $rest;
    }
    $fixed .= $rest if $fixed;
    warn $fixed if $fixed;
    $chunk = $fixed if $fixed;
  }
  print join '', @chunks;
}

1;
