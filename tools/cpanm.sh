#!/usr/bin/env bash

# Install module from cpan to this projects local lib using plx

YABSM_ROOT=$(realpath "$(dirname "$(readlink -f "$0")")"/..)

# work from project root
cd "$YABSM_ROOT" || (echo "error: could not cd to dir '$YABSM_ROOT'" >&2 && exit 1)

if ! [ -x "$(command -v plx)" ]; then
    echo "error: could not find program 'plx'" >&2
    exit 1
fi

plx --cpanm -Llocal "$@"
