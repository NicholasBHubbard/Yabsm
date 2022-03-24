#!/usr/bin/env bash

# fatpack yabsm into export/yabsm.fatpack.pl

YABSM_ROOT=$(realpath "$(dirname "$(readlink -f "$0")")"/..)

SRC_DIR="$YABSM_ROOT"/src
EXPORT_DIR="$YABSM_ROOT"/export
FATPACK="$YABSM_ROOT"/local/bin/fatpack

cd "$SRC_DIR" || (echo "error: could not cd to dir '$SRC_DIR'" >&2 && exit 1)

if ! [ -x "$(command -v plx)" ]; then
    echo "error: could not find program 'plx'" >&2
    exit 1
fi

plx --perl "$FATPACK" pack "$SRC_DIR"/yabsm.pl > "$EXPORT_DIR/yabsm.fatpack.pl"

rm -rf "$SRC_DIR"/fatlib
