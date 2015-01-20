#!/bin/sh

PERL5LIB=./lib:$PERL5LIB

fatten --overwrite --quiet --exclude-dist=Date-Manip -o dategrep-standalone-small bin/dategrep
fatten --overwrite --quiet --include-dist=Date-Manip -o dategrep-standalone-big   bin/dategrep
