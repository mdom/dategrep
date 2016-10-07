#!/bin/sh

set -e

PERL5LIB=./lib:$PERL5LIB

last_tag=$(git describe --abbrev=0 --tags)

github-release release --user mdom --repo dategrep --tag $last_tag

_fatten () {
	depak --overwrite --quiet --stripper --exclude-dist=Class-XSAccessor "$@" bin/dategrep
}

_fatten --exclude-dist=Date-Manip                   -o dategrep-standalone-small
_fatten --include-dist=Date-Manip --no-exclude-core -o dategrep-standalone-big

github-release upload --user mdom --repo dategrep --tag $last_tag --name dategrep-standalone-small --file dategrep-standalone-small
github-release upload --user mdom --repo dategrep --tag $last_tag --name dategrep-standalone-big   --file dategrep-standalone-big

