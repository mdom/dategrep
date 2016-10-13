#!/bin/sh

set -e

PERL5LIB=./lib:$PERL5LIB

last_tag=$(git describe --abbrev=0 --tags)

github-release release --user mdom --repo dategrep --tag $last_tag

_fatten () {
	depak --overwrite --quiet --stripper --include-dist=Method::Generate::BuildAll --exclude-dist=Class-XSAccessor "$@" bin/dategrep
}

_fatten --exclude-dist=Date-Manip -o dategrep-standalone-small
_fatten --include-dist=Date-Manip -o dategrep-standalone-big

./dategrep-standalone-small t/files/syslog01.log > /dev/null
./dategrep-standalone-big   t/files/syslog01.log > /dev/null

github-release upload --user mdom --repo dategrep --tag $last_tag --name dategrep-standalone-small --file dategrep-standalone-small
github-release upload --user mdom --repo dategrep --tag $last_tag --name dategrep-standalone-big   --file dategrep-standalone-big

export EMAIL="mario@domgoergen.com"
export NAME="Mario Domgoergen"

dch -v ${last_tag#v} -u low
dch -r

sbuild -d stable

github-release upload --user mdom --repo dategrep --tag $last_tag --name dategrep_${last_tag#v}-1_all.deb --file ../dategrep_${last_tag#v}-1_all.deb
