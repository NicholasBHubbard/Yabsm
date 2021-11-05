#!/bin/bash

cd "$(dirname "$0")" || echo 'error: could not change directory' && exit 1;

plx --perl ../local/bin/fatpack pack ../src/yabsm.pl > ../export/yabsm.fatpack.pl

rm -rf fatlib
