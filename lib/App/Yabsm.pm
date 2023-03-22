#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/Yabsm
#  License: GPL_3

#  This module contains the program's &main subroutine.

use strict;
use warnings;
use v5.34.0;

package App::Yabsm;

our $VERSION = '3.15.1';

use App::Yabsm::Command::Daemon;
use App::Yabsm::Command::Config;
use App::Yabsm::Command::Find;

sub usage {
    return <<'END_USAGE';
usage: yabsm [--help] [--version] [<COMMAND> <ARGS>]

See '$ man yabsm' for a detailed overview.

Commands:

  <daemon|d> [--help] [start] [stop] [restart] [status] [init]

  <config|c> [--help] [check ?file] [ssh-check <SSH_BACKUP>] [ssh-key]
             [yabsm-user-home] [yabsm_dir] [subvols] [snaps] [ssh_backups]
             [local_backups] [backups]

  <find|f>   [--help] [<SNAP|SSH_BACKUP|LOCAL_BACKUP> <QUERY>]

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
    if    ($cmd eq 'd') { $cmd = 'daemon' }
    elsif ($cmd eq 'c') { $cmd = 'config' }
    elsif ($cmd eq 'f') { $cmd = 'find'   }

    # All 3 subcommands have their own &main
    if    ($cmd eq 'daemon') { $cmd = \&App::Yabsm::Command::Daemon::main }
    elsif ($cmd eq 'config') { $cmd = \&App::Yabsm::Command::Config::main }
    elsif ($cmd eq 'find'  ) { $cmd = \&App::Yabsm::Command::Find::main   }
    else {
        die usage();
    }

    $cmd->(@args);

    exit 0;
}

1;
