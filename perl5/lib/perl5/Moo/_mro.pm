package Moo::_mro;
use Moo::_strictures;

if ($] >= 5.010) {
  require mro;
} else {
  require MRO::Compat;
}

1;
