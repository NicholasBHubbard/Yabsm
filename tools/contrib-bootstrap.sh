#!/usr/bin/env bash

# Bootstrap an environment for hacking on YABSM.

SCRIPT=${0##*/}

YABSM_ROOT=$(realpath "$(dirname "$(readlink -f "$0")")"/..)

cd "$YABSM_ROOT" || (echo "error: could not cd to dir '$YABSM_ROOT'" >&2 && exit 1)

USAGE=$(cat <<EOF
usage: $SCRIPT [OPTIONS]
Options are:
  -h            Show this help message.
  -d directory  Install Perl v5.16.3 to DIRECTORY. By default installs to 
                \$HOME/perl5.
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

PERL_BUILD_DIR=${PERL_BUILD_DIR:-"$HOME/perl5"}
PERL_EXECUTABLE="$PERL_BUILD_DIR/bin/perl"

PERL_BUILD_COMMAND="curl -L https://raw.githubusercontent.com/tokuhirom/Perl-Build/master/perl-build | perl - 5.16.3 $PERL_BUILD_DIR"

PLX_DIR="$YABSM_ROOT/.plx"
PLX_EXECUTABLE="$PLX_DIR/plx"
PLX_INSTALL_COMMAND="mkdir $PLX_DIR ; wget https://raw.githubusercontent.com/shadowcat-mst/plx/master/bin/plx-packed -O $PLX_EXECUTABLE"

YABSM_DEPENDENCIES='lib::relative@1.000 Array::Utils@0.5 App::FatPacker@0.10.8 Net::OpenSSH@0.80 Parser::MGC@0.19 Test::Exception@0.43'

eval "$PERL_BUILD_COMMAND"
eval "$PLX_INSTALL_COMMAND"

$PLX_EXECUTABLE --init "$PERL_EXECUTABLE" 

$PLX_EXECUTABLE --cpanm -Llocal "$YABSM_DEPENDENCIES"
