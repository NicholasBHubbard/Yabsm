#  Author:    Nicholas Hubbard
#  Copyright: Nicholas Hubbard
#  License:   GPL_3
#  WWW:       https://github.com/NicholasBHubbard/Yabsm

#  This module contains the program's &main subroutine.

use strict;
use warnings;
use v5.34.0;

package App::Yabsm;

our $VERSION = '4.0.0';

use App::Yabsm::Command::Config;
use App::Yabsm::Command::Find;
use App::Yabsm::Command::Start;

sub usage {
    return <<'END_USAGE';
usage: yabsm [--help] [--version] [<COMMAND> <ARGS>]

See '$ man yabsm' for a detailed overview.

Commands:

  <config|c> [--help] [check ?file] [ssh-check <SSH_BACKUP>] [ssh-key]
             [yabsm-user-home] [yabsm_dir] [subvols] [snaps] [ssh_backups]
             [local_backups] [backups]

  <find|f>   [--help] [<SNAP|SSH_BACKUP|LOCAL_BACKUP> <QUERY>]

  <start|s>  [--help]

END_USAGE
}

sub main {

    # This is the toplevel subroutine of Yabsm. It is invoked directly from
    # bin/yabsm with @ARGV as its args.

    my $cmd = shift @_ or die usage();

    my @args = @_;

    if ($cmd =~ /^(-h|--help)$/) { print usage() and exit 0 }
    if ($cmd eq '--version')     { say $VERSION  and exit 0 }

    # Provide user with command abbreviations
    if    ($cmd eq 'c') { $cmd = 'config' }
    elsif ($cmd eq 'f') { $cmd = 'find'   }
    elsif ($cmd eq 's') { $cmd = 'start'  }

    # All 3 subcommands have their own &main
    if    ($cmd eq 'config') { $cmd = \&App::Yabsm::Command::Config::main }
    elsif ($cmd eq 'find'  ) { $cmd = \&App::Yabsm::Command::Find::main   }
    elsif ($cmd eq 'start' ) { $cmd = \&App::Yabsm::Command::Start::main  }
    else {
        die usage();
    }

    $cmd->(@args);

    exit 0;
}

1;
