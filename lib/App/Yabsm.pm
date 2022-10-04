#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  The main module of Yabsm.

#  ABSTRACT: a btrfs snapshot and backup management system

use strict;
use warnings;
use v5.16.3;

package App::Yabsm;

our $VERSION = '3.14';

use App::Yabsm::Command::Daemon;
use App::Yabsm::Command::Config;
use App::Yabsm::Command::Find;

sub usage {
    return <<'END_USAGE';
usage: yabsm [--help] [--version] [<COMMAND> <ARGS>]

see 'man yabsm' for a detailed overview of yabsm.

commands:

<config|c> [--help] [check ?file] [ssh-check <SSH_BACKUP>] [ssh-key]
           [yabsm-user-home] [yabsm_dir] [subvols] [snaps] [ssh_backups]
           [local_backups] [backups]

<find|f>   [--help] [<SNAP|SSH_BACKUP|LOCAL_BACKUP> <QUERY>]

<daemon|d> [--help] [start] [stop] [restart] [status] [init]
END_USAGE
}

sub main {

    # This is the toplevel subroutine of Yabsm.

    my $cmd = shift @_ or die usage();

    my @args = @_;

    if ($cmd =~ /^(-h|--help)$/) { print usage() and exit 0 }
    if ($cmd eq '--version')     { say $VERSION  and exit 0 }

    # provide user with command abbreviations
    if    ($cmd eq 'd') { $cmd = 'daemon' }
    elsif ($cmd eq 'c') { $cmd = 'config' }
    elsif ($cmd eq 'f') { $cmd = 'find'   }

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
