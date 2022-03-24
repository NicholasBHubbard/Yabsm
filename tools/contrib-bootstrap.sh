#!/usr/bin/env bash

# Bootstrap an environment for hacking on YABSM.

set -e

SCRIPT=${0##*/}

YABSM_ROOT=$(realpath "$(dirname "$(readlink -f "$0")")"/..)

cd "$YABSM_ROOT" || (echo "error: could not cd to dir '$YABSM_ROOT'" >&2 && exit 1)

USAGE=$(cat <<EOF
usage: $SCRIPT [OPTIONS]
Options are:
  -h            Show this help message.
  -d directory  Install Perl v5.16.3 to DIRECTORY. By default installs to 
                \$HOME/perl-5.16.3.
EOF
)

while [ -n "$1" ]; do
  k="$1"
  shift
  case $k in
    -d)
      PERL_BUILD_DIR="$1"
      shift
      ;;
    -h)
      echo "$USAGE"
      exit 0
      ;;
    *)
      echo "$USAGE"
      exit 1
      ;;
  esac  
done

PERL_BUILD_DIR=${PERL_BUILD_DIR:-"$HOME/perl-5.16.3"}
PERL_EXECUTABLE="$PERL_BUILD_DIR/bin/perl"

PERL_BUILD_COMMAND="curl -L https://raw.githubusercontent.com/tokuhirom/Perl-Build/master/perl-build | perl - 5.16.3 $PERL_BUILD_DIR"

PLX_EXECUTABLE="$YABSM_ROOT/plx"
PLX_INSTALL_COMMAND="wget https://raw.githubusercontent.com/shadowcat-mst/plx/master/bin/plx-packed -O $PLX_EXECUTABLE"

echo "$SCRIPT: Executing: $PERL_BUILD_COMMAND"
eval "$PERL_BUILD_COMMAND"

echo "$SCRIPT: Executing: $PLX_INSTALL_COMMAND"
eval "$PLX_INSTALL_COMMAND"

chmod 0774 "$PLX_EXECUTABLE"

$PLX_EXECUTABLE --init "$PERL_EXECUTABLE"
mv "$PLX_EXECUTABLE" "$YABSM_ROOT/.plx"
PLX_EXECUTABLE="$YABSM_ROOT/.plx/plx"

YABSM_DEPENDENCIES='lib::relative@1.000 Array::Utils@0.5 App::FatPacker@0.10.8 Net::OpenSSH@0.80 Parser::MGC@0.19 Test::Exception@0.43'
$PLX_EXECUTABLE --cpanm -L local -i "$YABSM_DEPENDENCIES"
