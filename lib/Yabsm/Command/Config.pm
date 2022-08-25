#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Provides functions for querying information about the users config.

use strict;
use warnings;
use v5.16.3;

package Yabsm::Command::Config;

use Yabsm::Tools qw( :ALL );
use Yabsm::Config::Query qw( :ALL );
use Yabsm::Config::Parser 'parse_config_or_die';
use POSIX;

use Net::OpenSSH;

                 ####################################
                 #               MAIN               #
                 ####################################

my $usage = 'usage: yabsm config <subvols|snaps|ssh_backups|local_backups|backups|check|check_ssh_backup SSH_BACKUP>'."\n";

sub main {

    my $cmd = shift or die $usage;

    if    ($cmd eq 'subvols'          ) { print_subvols(@_)       }
    elsif ($cmd eq 'snaps'            ) { print_snaps(@_)         }
    elsif ($cmd eq 'ssh_backups'      ) { print_ssh_backups(@_)   }
    elsif ($cmd eq 'local_backups'    ) { print_local_backups(@_) }
    elsif ($cmd eq 'backups'          ) { print_backups(@_)       }
    elsif ($cmd eq 'check'            ) { check_config(@_)        }
    elsif ($cmd eq 'check_ssh_backup' ) { check_config(@_)        }
    else {
        die $usage;
    }

    exit 0;
}

                 ####################################
                 #            SUBROUTINES           #
                 ####################################

sub print_subvols {
    0 == @_ or die $usage;
    my $config_ref = parse_config_or_die();
    say for all_subvols($config_ref);
    return 1;
}

sub print_snaps {
    0 == @_ or die $usage;
    my $config_ref = parse_config_or_die();
    say for all_snaps($config_ref);
    return 1;
}

sub print_ssh_backups {
    0 == @_ or die $usage;
    my $config_ref = parse_config_or_die();
    say for all_ssh_backups($config_ref);
    return 1;
}

sub print_local_backups {
    0 == @_ or die $usage;
    my $config_ref = parse_config_or_die();
    say for all_local_backups($config_ref);
    return 1;
}

sub print_backups {
    0 == @_ or die $usage;
    my $config_ref = parse_config_or_die();
    my @ssh_backups = all_ssh_backups($config_ref);
    my @local_backups = all_local_backups($config_ref);
    say for sort @ssh_backups, @local_backups;
    return 1;
}

sub check_config {
    1 >= @_ or die $usage;
    my $file = shift // '/etc/yabsm.conf';
    my $config_ref = parse_config_or_die($file);
    say 'all good';
    return 1;
}

sub check_ssh_backup {
    1 == @_ or die $usage;
    my $ssh_backup = shift;
    my $config_ref = parse_config_or_die();
    unless (ssh_backup_exists($ssh_backup, $config_ref)) {
        die "yabsm: error: no ssh_backup named '$ssh_backup'\n";
    }
    die "yabsm: error: permission denied\n" unless i_am_root();

}

1;
