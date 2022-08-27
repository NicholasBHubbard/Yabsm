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

                 ####################################
                 #               MAIN               #
                 ####################################

my $usage = 'usage: yabsm config <subvols|snaps|ssh_backups|local_backups|backups|check'."\n";

sub main {

    my $cmd = shift or die $usage;

    if    ($cmd eq 'subvols'          ) { print_subvols(@_)       }
    elsif ($cmd eq 'snaps'            ) { print_snaps(@_)         }
    elsif ($cmd eq 'ssh_backups'      ) { print_ssh_backups(@_)   }
    elsif ($cmd eq 'local_backups'    ) { print_local_backups(@_) }
    elsif ($cmd eq 'backups'          ) { print_backups(@_)       }
    elsif ($cmd eq 'check'            ) { check_config(@_)        }
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
}

sub print_snaps {
    0 == @_ or die $usage;
    my $config_ref = parse_config_or_die();
    say for all_snaps($config_ref);
}

sub print_ssh_backups {
    0 == @_ or die $usage;
    my $config_ref = parse_config_or_die();
    say for all_ssh_backups($config_ref);
}

sub print_local_backups {
    0 == @_ or die $usage;
    my $config_ref = parse_config_or_die();
    say for all_local_backups($config_ref);
}

sub print_backups {
    0 == @_ or die $usage;
    my $config_ref = parse_config_or_die();
    my @ssh_backups = all_ssh_backups($config_ref);
    my @local_backups = all_local_backups($config_ref);
    say for sort @ssh_backups, @local_backups;
}

sub check_config {
    1 >= @_ or die $usage;
    my $file = shift // '/etc/yabsm.conf';
    parse_config_or_die($file);
    say 'all good';
}

1;
