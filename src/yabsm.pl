#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  This is the toplevel script of yabsm. The actual program that is
#  installed on the end users system is this script but fatpacked.

use strict;
use warnings;
use v5.16.3;

die "error: your perl version '$]' is less than 5.16.3" if $] < 5.016003;

my $YABSM_VERSION = 2.1;

sub usage {
    print <<END_USAGE;
usage: yabsm [--help] [--version]
             <command> [<args>]

  find, f <SUBJECT> <QUERY>               Find a snapshot of SUBJECT using
                                          QUERY. SUBJECT must be a backup or
                                          subvol defined in /etc/yabsm.conf.

  check-config, c <?FILE>                 Check that FILE is a valid yabsm
                                          config file for errors. If FILE is
                                          not specified then check
                                          /etc/yabsm.conf. If errors are present
                                          print their messages to stderr and 
                                          exit with non zero status, else print
                                          'all good'.

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

  print-subvols, subvols                  Print the names of all the subvols 
                                          defined in /etc/yabsm.conf.

  print-backups, backups                  Print the names of all the backups 
                                          defined in /etc/yabsm.conf.

  test-remote-config, tr <BACKUP>         Test that the remote BACKUP has been 
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
use Yabsm::Commands::TakeSnap;
use Yabsm::Commands::IncrementalBackup;
use Yabsm::Commands::BackupBootstrap;
use Yabsm::Commands::Find;
use Yabsm::Commands::PrintSubvols;
use Yabsm::Commands::PrintBackups;
use Yabsm::Commands::CheckConfig;
use Yabsm::Commands::UpdateEtcCrontab;
use Yabsm::Commands::PrintCrons;
use Yabsm::Commands::TestRemoteBackupConfig;

# command dispatch table
my %run_command =
   ( 'take-snap'          => \&Yabsm::Commands::TakeSnap::main
   , 'incremental-backup' => \&Yabsm::Commands::IncrementalBackup::main
   , 'bootstrap-backup'   => \&Yabsm::Commands::BackupBootstrap::main
   , 'find'               => \&Yabsm::Commands::Find::main
   , 'print-subvols'      => \&Yabsm::Commands::PrintSubvols::main
   , 'print-backups'      => \&Yabsm::Commands::PrintBackups::main
   , 'check-config'       => \&Yabsm::Commands::CheckConfig::main
   , 'update-crontab'     => \&Yabsm::Commands::UpdateEtcCrontab::main
   , 'print-crons'        => \&Yabsm::Commands::PrintCrons::main
   , 'test-remote-config' => \&Yabsm::Commands::TestRemoteBackupConfig::main
   );

sub unabbreviate {

    # provide the user with convenient command abbreviations

    my $cmd = shift // die;

    if    ($cmd eq 'snap')      { return 'take-snap'          }
    elsif ($cmd eq 'backup')    { return 'incremental-backup' }
    elsif ($cmd eq 'bootstrap') { return 'bootstrap-backup'   }
    elsif ($cmd eq 'f')         { return 'find'               }
    elsif ($cmd eq 'subvols')   { return 'print-subvols'      }
    elsif ($cmd eq 'backups')   { return 'print-backups'      }
    elsif ($cmd eq 'c')         { return 'check-config'       }
    elsif ($cmd eq 'update')    { return 'update-crontab'     }
    elsif ($cmd eq 'crons')     { return 'print-crons'        }
    elsif ($cmd eq 'tr')        { return 'test-remote-config' }
    else                        { return $cmd                 }
}

                 ####################################
                 #               MAIN               #
                 ####################################

my $cmd = shift @ARGV || (usage() and exit 1);

if ($cmd eq '--help' || $cmd eq '-h') { usage() and exit 0 }

if ($cmd eq '--version') { say $YABSM_VERSION and exit 0 }

my $full_cmd = unabbreviate($cmd);

if (not exists $run_command{ $full_cmd} ) {
    die "yabsm: error: no such command '$cmd'\n";
}

$run_command{ $full_cmd }->(@ARGV);

exit 0; # all good
