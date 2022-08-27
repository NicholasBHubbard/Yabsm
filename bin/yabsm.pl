#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  TODO

our $VERSION = '3.11';

use strict;
use warnings;
use v5.16.3;

use Yabsm::Tools 'arg_count_or_die';

sub usage {
    print <<END_USAGE;
usage: yabsm [--help] [--version] <command> <arg(s)>

  daemon [start|stop|restart|status]      Execute a yabsm daemon command.
END_USAGE
}

use Yabsm::Command::Daemon;
use Yabsm::Command::Config;
use Yabsm::Command::Find;

# subcommand dispatch table
my %run_subcommand = (
    'daemon' => \&Yabsm::Command::Daemon::main,
    'config' => \&Yabsm::Command::Config::main,
    'find'   => \&Yabsm::Command::Find::main
);

sub unabbreviate_cmd {

    # Provide the user with command abbreviations

    arg_count_or_die(1, 1, @_);

    my $cmd = shift;

    if    ($cmd eq 'c')       { return 'config' }
    elsif ($cmd eq 'f')       { return 'find'   }
    else                      { return $cmd     }
}

                 ####################################
                 #               MAIN               #
                 ####################################

my $cmd = shift @ARGV || (usage() and exit 1);

if ($cmd eq '--help' || $cmd eq '-h') { usage() and exit 0 }

if ($cmd eq '--version') { say $VERSION and exit 0 }

my $full_cmd = unabbreviate_cmd($cmd);

exists $run_subcommand{ $full_cmd} || (usage() and exit 1);

$run_subcommand{ $full_cmd }->(@ARGV);
