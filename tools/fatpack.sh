#!/bin/sh

# path to this script
P="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 || exit 1 ; pwd -P )"

plx --perl "$P"/../local/bin/fatpack pack "$P"/../src/yabsm.pl > "$P"/../export/yabsm.fatpack.pl

rm -rf "$P"/fatlib
