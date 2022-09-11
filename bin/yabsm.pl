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

use Yabsm::Command::Daemon;
use Yabsm::Command::Config;
use Yabsm::Command::Find;
use Yabsm::Command::SSH;

sub usage {

    arg_count_or_die(0, 0, @_);

    my $config_usage = Yabsm::Command::Config::usage();
    my $find_usage   = Yabsm::Command::Find::usage();
    my $ssh_usage    = Yabsm::Command::SSH::usage();
    my $daemon_usage = Yabsm::Command::Daemon::usage();

    s/^usage: yabsm: |\s+$//g for $daemon_usage, $config_usage, $find_usage, $ssh_usage;

    print <<"END_USAGE";
usage: yabsm [--help] [--version] [<COMMAND> ?ARGS]

commands:

$config_usage
$find_usage
$ssh_usage
$daemon_usage
END_USAGE
}

sub unabbreviate_cmd {

    # Provide the user with command abbreviations

    arg_count_or_die(1, 1, @_);

    my $cmd = shift;

    if    ($cmd eq 'c') { return 'config' }
    elsif ($cmd eq 'f') { return 'find'   }
    elsif ($cmd eq 'd') { return 'daemon' }
    else                { return $cmd     }
}

# subcommand dispatch table
my %run_subcommand = (
    'config' => \&Yabsm::Command::Config::main,
    'find'   => \&Yabsm::Command::Find::main,
    'ssh'    => \&Yabsm::Command::SSH::main,
    'daemon' => \&Yabsm::Command::Daemon::main
);

                 ####################################
                 #               MAIN               #
                 ####################################

my $cmd = shift @ARGV || (usage() and exit 1);

if ($cmd eq '--help' || $cmd eq '-h') { usage() and exit 0 }

if ($cmd eq '--version') { say $VERSION and exit 0 }

$cmd = unabbreviate_cmd($cmd);

exists $run_subcommand{ $cmd} || (usage() and exit 1);

$run_subcommand{ $cmd }->(@ARGV);

exit 0;
