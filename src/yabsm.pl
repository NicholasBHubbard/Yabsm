#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT
#
#  yabsm is a btrfs snapshot manager.

use strict;
use warnings;
use v5.16.3;

die "error: your perl version '$]' is less than 5.16.3" if $] < 5.016003;

my $YABSM_VERSION = 2.1;

sub usage {
    print <<END_USAGE;
usage: yabsm [--help] [--version]
             <command> [<args>]

  Use one of the following commands:

  find, f <SUBJECT> <QUERY>               Find a snapshot of SUBJECT using
                                          QUERY. SUBJECT must be a backup or
                                          subvol defined in /etc/yabsm.conf.

  check-config, check <?FILE>             Check that FILE is a valid yabsm
                                          config file for errors. If FILE is
                                          not specified then check
                                          /etc/yabsm.conf. If errors are present
                                          print their messages to stderr and 
                                          exit with non zero status, else print
                                          'all good' to stdout.

  update-crontab, update                  Update cronjobs in /etc/crontab, based
                                          off the user settings specified in 
                                          /etc/yabsm.conf. This is a root only 
                                          command.

  print-crons, crons                      Display the cronjob strings that would
                                          be written to /etc/crontab if the
                                          update-crontab command were used.

  take-snap, snap <SUBVOL> <TIMEFRAME>    Take a new snapshot of SUBVOL for the
                                          TIMEFRAME category. It is not
                                          recommended to use this command
                                          manually. This is a root only command.

  incremental-backup, backup <BACKUP>     Perform an incremental backup of
                                          BACKUP. It is not recommended to use
                                          this command manually. This is a root
                                          only command.

  bootstrap-backup, bootstrap <BACKUP>    Perform the boostrap phase of the
                                          btrfs incremental backup process for
                                          BACKUP. This is a root only command.

  print-subvols, subvols                  Print all the subvols defined in
                                          /etc/yabsm.conf to stdout.

  print-backups, backups                  Print all the backups defined in
                                          /etc/yabsm.conf to stdout.

  test-remote-conf, test-remote <BACKUP>  Test that the remote BACKUP has been 
                                          properly configured. For BACKUP to be 
                                          properly configured yabsm should be
                                          able to connect to the remote host and
                                          use the btrfs command with sudo 
                                          without having to enter any passwords.
                                          This is a root only command.

  Please see 'man yabsm' for more detailed information about yabsm.
END_USAGE
}

use lib::relative 'lib';

# Every command has their own module with a main() function
use App::Commands::TakeSnap;
use App::Commands::IncrementalBackup;
use App::Commands::BackupBootstrap;
use App::Commands::Find;
use App::Commands::PrintSubvols;
use App::Commands::PrintBackups;
use App::Commands::CheckConfig;
use App::Commands::UpdateEtcCrontab;
use App::Commands::PrintCrons;
use App::Commands::TestRemoteBackupConfig;

# command dispatch table
my %run_command =
   ( 'take-snap'          => \&App::Commands::TakeSnap::main
   , 'incremental-backup' => \&App::Commands::IncrementalBackup::main
   , 'bootstrap-backup'   => \&App::Commands::BackupBootstrap::main
   , 'find'               => \&App::Commands::Find::main
   , 'print-subvols'      => \&App::Commands::PrintSubvols::main
   , 'print-backups'      => \&App::Commands::PrintBackups::main
   , 'check-config'       => \&App::Commands::CheckConfig::main
   , 'update-crontab'     => \&App::Commands::UpdateEtcCrontab::main
   , 'print-crons'        => \&App::Commands::PrintCrons::main
   , 'test-remote-conf'   => \&App::Commands::TestRemoteBackupConfig::main
   );

sub unabbreviate {

    # provide the user with convenient command abbreviations

    my $cmd = shift // die;

    if    ($cmd eq 'snap')        { return 'take-snap'          }
    elsif ($cmd eq 'backup')      { return 'incremental-backup' }
    elsif ($cmd eq 'bootstrap')   { return 'bootstrap-backup'   }
    elsif ($cmd eq 'f')           { return 'find'               }
    elsif ($cmd eq 'subvols')     { return 'print-subvols'      }
    elsif ($cmd eq 'backups')     { return 'print-backups'      }
    elsif ($cmd eq 'check')       { return 'check-config'       }
    elsif ($cmd eq 'update')      { return 'update-crontab'     }
    elsif ($cmd eq 'crons')       { return 'print-crons'        }
    elsif ($cmd eq 'test-remote') { return 'test-remote-conf'   }
    else                          { return $cmd                 }
}

                 ####################################
                 #               MAIN               #
                 ####################################

my $cmd = shift @ARGV || (usage() and exit 1);

if ($cmd eq '--help' || $cmd eq '-h') { usage() and exit 0 }

if ($cmd eq '--version') { say $YABSM_VERSION and exit 0 }

my $full_cmd = unabbreviate($cmd);

if (not exists $run_command{ $full_cmd} ) {
    die "error: no such command '$cmd'\n";
}

$run_command{ $full_cmd }->(@ARGV);

exit 0; # all good
