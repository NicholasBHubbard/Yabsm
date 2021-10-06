#!/usr/bin/env perl

#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT
#
#  yabsm is a btrfs snapshot manager.

use strict;
use warnings;
use 5.010;

my $VERSION = 2.1;

sub usage {
    print <<END_USAGE;
Usage: yabsm [--help] [--version]
             <command> [<args>]

  Use exactly one of the following commands:

  find, f <SUBJECT> <QUERY>               Find a snapshot of SUBJECT using
                                          QUERY. SUBJECT must be a backup or
                                          subvol defined in /etc/yabsmrc.

  check-config, check <?FILE>             Check that FILE is a valid yabsm 
                                          config file for errors. If FILE is
                                          not specified then check /etc/yabsmrc.
                                          If errors are present print their 
                                          messages to stderr and exist with non
                                          zero status, else print 'all good' to
                                          stdout.

  update-crontab, update                  Update cronjobs in /etc/crontab, based
                                          off the user settings specified in 
                                          /etc/yabsmrc. This is a root only 
                                          option.

  print-crons, crons                      Display the cronjob strings that would
                                          be written to /etc/crontab if the
                                          update-crontab command were used.

  take-snap, snap <SUBVOL> <TIMEFRAME>    Take a new snapshot of SUBVOL for the
                                          TIMEFRAME category. It is not
                                          recommended to use this option
                                          manually. This is a root only option.

  incremental-backup, backup <BACKUP>     Perform an incremental backup of
                                          BACKUP. It is not recommended to use
                                          this option manually. This is a root
                                          only option.

  print-subvols, subvols                  Print all the subvols defined in
                                          /etc/yabsmrc to stdout.

  print-backups, backups                  Print all the backups defined in
                                          /etc/yabsmrc to stdout.

  bootstrap-backup, bootstrap <BACKUP>    Perform the boostrap phase of the
                                          btrfs incremental backup process for
                                          BACKUP. This is a root only option.

  test-remote-backup, test <BACKUP>       Test that BACKUP has been properly
                                          configured. For BACKUP to be properly
                                          configured yabsm should be able to
                                          connect to the remote host and use the
                                          btrfs command with sudo without having
                                          to enter any passwords. This is a root
                                          only option.

  Please see 'man yabsm' for more detailed information about yabsm.
END_USAGE
}

use FindBin '$Bin';
use lib "$Bin/lib";

# Every sub-command has their own module with a main() function
use Yabsm::TakeSnap;
use Yabsm::IncrementalBackup;
use Yabsm::BackupBootstrap;
use Yabsm::Find;
use Yabsm::PrintSubvols;
use Yabsm::PrintBackups;
use Yabsm::CheckConfig;
use Yabsm::UpdateEtcCrontab;
use Yabsm::PrintCrons;
use Yabsm::TestRemoteBackupConfig;

# command dispatch table
my %run_command = ( 'take-snap'          => \&Yabsm::TakeSnap::main
	          , 'incremental-backup' => \&Yabsm::IncrementalBackup::main
	          , 'bootstrap-backup'   => \&Yabsm::BackupBootstrap::main
	          , 'find'               => \&Yabsm::Find::main
		  , 'print-subvols'      => \&Yabsm::PrintSubvols::main
		  , 'print-backups'      => \&Yabsm::PrintBackups::main
	          , 'check-config'       => \&Yabsm::CheckConfig::main
	          , 'update-crontab'     => \&Yabsm::UpdateEtcCrontab::main
	          , 'print-crons'        => \&Yabsm::PrintCrons::main
	          , 'test-remote-backup' => \&Yabsm::TestRemoteBackupConfig::main
	          );

sub unabbreviate {

    my $cmd = shift // die;

    if    ($cmd eq 'snap')            { return 'take-snap'          }
    elsif ($cmd eq 'backup')          { return 'incremental-backup' }
    elsif ($cmd eq 'bootstrap')       { return 'bootstrap-backup'   }
    elsif ($cmd eq 'f')               { return 'find'               }
    elsif ($cmd eq 'subvols')         { return 'print-subvols'      }
    elsif ($cmd eq 'backups')         { return 'print-backups'      }
    elsif ($cmd eq 'check')           { return 'check-config'       }
    elsif ($cmd eq 'update')          { return 'update-crontab'     }
    elsif ($cmd eq 'crons')           { return 'print-crons'        }
    elsif ($cmd eq 'test')            { return 'test-remote-backup' }
    else                              { return $cmd                 }
}

                 ####################################
                 #               MAIN               #
                 ####################################

my $cmd = shift @ARGV || (usage() and exit 1);

if ($cmd eq '--help' || $cmd eq '-h') { usage() and exit 0 }

if ($cmd eq '--version') { say $VERSION and exit 0 }

my $full_cmd = unabbreviate($cmd);

if (not exists $run_command{ $full_cmd} ) {
    die "yabsm: '$cmd' is not a yabsm command. See 'yabsm --help'.\n"
}

$run_command{ $full_cmd }->(@ARGV);

exit 0; # all good

