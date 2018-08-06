#!/bin/sh
#
# Make a dategrep release.
#

export EMAIL="mario@domgoergen.com"
export NAME="Mario Domgoergen"

set -e

PERL5LIB="./lib:${PERL5LIB}"

last_tag="$(git describe --abbrev=0 --tags)"

github-release release --user mdom --repo dategrep --tag "$last_tag"

./build-standalone > dategrep
./dategrep t/files/syslog01.log > /dev/null

github-release upload --user mdom --repo dategrep --tag "$last_tag" --name dategrep --file dategrep

echo "OK."
