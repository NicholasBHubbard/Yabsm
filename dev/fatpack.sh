#!/bin/sh

if ! command -v fatpack-simple
then
    echo "fatpack-simple could not be found"
    exit
fi

fatpack-simple -o ../yabsm.fatpack.pl ../src/yabsm.pl
