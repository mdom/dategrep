#!/bin/sh

set -e

PERL5LIB=./lib:$PERL5LIB

last_tag=$(git describe --abbrev=0 --tags)

github-release release --user mdom --repo dategrep --tag $last_tag

fatten --overwrite --quiet --exclude-dist=Date-Manip -o dategrep-standalone-small bin/dategrep
fatten --overwrite --quiet --include-dist=Date-Manip -o dategrep-standalone-big   bin/dategrep

github-release upload --user mdom --repo dategrep --tag $last_tag --name dategrep-standalone-small --file dategrep-standalone-small
github-release upload --user mdom --repo dategrep --tag $last_tag --name dategrep-standalone-big   --file dategrep-standalone-big

