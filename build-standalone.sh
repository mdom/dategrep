#!/bin/sh

set -e

PERL5LIB=./lib:$PERL5LIB

fatten --overwrite --quiet --exclude-dist=Date-Manip -o dategrep-standalone-small bin/dategrep
fatten --overwrite --quiet --include-dist=Date-Manip -o dategrep-standalone-big   bin/dategrep

git checkout gh-pages
mv dategrep-standalone-small dategrep-standalone-small.pl
mv dategrep-standalone-big   dategrep-standalone-big.pl

git commit -am 'rebuild scripts'
git push

git checkout master
