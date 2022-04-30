#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  This is the toplevel script of yabsm. The actual program that is
#  installed on the end users system is this script but fatpacked.

our $VERSION = '3.1.0';

use strict;
use warnings;
use v5.16.3;

sub usage {
    print <<END_USAGE;
yabsm: usage: yabsm [--help] [--version] <command> <arg(s)>

  find, f <SUBJECT> <QUERY>               Find a snapshot of SUBJECT using
                                          QUERY. SUBJECT must be a backup or
                                          subvol defined in /etc/yabsm.conf.

  update-crontab, update                  Write cronjobs to /etc/crontab, based
                                          off the settings specified in
                                          /etc/yabsm.conf. This is a root only
                                          command.

  check-config, c <?FILE>                 Check that FILE is a valid yabsm
                                          config file. If FILE is not specified
                                          then check /etc/yabsm.conf. If errors
                                          are present print their messages to
                                          stderr and exit with non zero status,
                                          else print 'all good'.

  test-remote-config, tr <BACKUP>         Test that the remote BACKUP has been
                                          properly configured. For BACKUP to be
                                          properly configured yabsm should be
                                          able to connect to the remote host and
                                          use the btrfs command with sudo
                                          without having to enter any passwords.
                                          This is a root only command.

  bootstrap-backup, bootstrap <BACKUP>    Perform the boostrap phase of the
                                          btrfs incremental backup process for
                                          BACKUP. This is a root only command.

  print-crons, crons                      Print the cronjob strings that would
                                          be written to /etc/crontab if the
                                          update-crontab command were used.

  print-subvols, subvols                  Print the names of all the subvols
                                          defined in /etc/yabsm.conf.

  print-backups, backups                  Print the names of all the backups
                                          defined in /etc/yabsm.conf.

  take-snap SUBVOL TIMEFRAME              Take a single read-only snapshot of
                                          SUBVOL and put it in the TIMEFRAME
                                          directory. This command should only
                                          be used manually for debugging
                                          purposes. This is a root only command.

  incremental-backup BACKUP               Perform a single incremental backup
                                          of BACKUP. This command should only
                                          be used manually for debugging
                                          purposes. This is a root only command.
END_USAGE
}

use lib::relative 'lib';

# Every command has their own module with a main() function
use Yabsm::Commands::TakeSnap;
use Yabsm::Commands::IncrementalBackup;
use Yabsm::Commands::Find;
use Yabsm::Commands::UpdateEtcCrontab;
use Yabsm::Commands::CheckConfig;
use Yabsm::Commands::TestRemoteBackupConfig;
use Yabsm::Commands::BackupBootstrap;
use Yabsm::Commands::PrintCrons;
use Yabsm::Commands::PrintSubvols;
use Yabsm::Commands::PrintBackups;

# command dispatch table
my %run_command =
   ( 'take-snap'          => \&Yabsm::Commands::TakeSnap::main
   , 'incremental-backup' => \&Yabsm::Commands::IncrementalBackup::main
   , 'find'               => \&Yabsm::Commands::Find::main
   , 'update-crontab'     => \&Yabsm::Commands::UpdateEtcCrontab::main
   , 'check-config'       => \&Yabsm::Commands::CheckConfig::main
   , 'test-remote-config' => \&Yabsm::Commands::TestRemoteBackupConfig::main
   , 'bootstrap-backup'   => \&Yabsm::Commands::BackupBootstrap::main
   , 'print-crons'        => \&Yabsm::Commands::PrintCrons::main
   , 'print-subvols'      => \&Yabsm::Commands::PrintSubvols::main
   , 'print-backups'      => \&Yabsm::Commands::PrintBackups::main
   );

sub unabbreviate {

    # provide the user with command abbreviations

    my $cmd = shift // die;

    if    ($cmd eq 'f')         { return 'find'               }
    elsif ($cmd eq 'update')    { return 'update-crontab'     }
    elsif ($cmd eq 'c')         { return 'check-config'       }
    elsif ($cmd eq 'tr')        { return 'test-remote-config' }
    elsif ($cmd eq 'bootstrap') { return 'bootstrap-backup'   }
    elsif ($cmd eq 'crons')     { return 'print-crons'        }
    elsif ($cmd eq 'subvols')   { return 'print-subvols'      }
    elsif ($cmd eq 'backups')   { return 'print-backups'      }
    else                        { return $cmd                 }
}

                 ####################################
                 #               MAIN               #
                 ####################################

my $cmd = shift @ARGV || (usage() and exit 1);

if ($cmd eq '--help' || $cmd eq '-h') { usage() and exit 0 }

if ($cmd eq '--version') { say $VERSION and exit 0 }

my $full_cmd = unabbreviate($cmd);

if (not exists $run_command{ $full_cmd} ) {
    die "yabsm: error: no such command '$cmd'\n";
}

$run_command{ $full_cmd }->(@ARGV);

exit 0; # all good
