#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Provides functionality for querying information about the users config.

use strict;
use warnings;
use v5.16.3;

package Yabsm::Command::Config;

use Yabsm::Tools qw( :ALL );
use Yabsm::Config::Query qw( :ALL );
use Yabsm::Config::Parser 'parse_config_or_die';

sub usage {
    arg_count_or_die(0, 0, @_);
    return <<"END_USAGE";
usage: yabsm config [--help] [check ?file] [yabsm_user_home] [yabsm_dir]
                    [subvols] [ssh_backups] [local_backups] [backups]
END_USAGE
}

sub help {
    0 == @_ or die usage();
    my $usage = usage() =~ s/\s+$//r;
    print <<"END_HELP";
$usage

--help           Print this help message.

check ?file      Check ?file for errors and print their messages. If ?file is
                 omitted it defaults to /etc/yabsm.conf.

yabsm_user_home  Print the yabsm users home directory.

yabsm_dir        Print the value of yabsm_dir in /etc/yabsm.conf.

subvols          Print the names of all subvols defined in /etc/yabsm.conf.

ssh_backups      Print the names of all ssh_backups defined in /etc/yabsm.conf.

local_backups    Print the names of all local_backups defined in /etc/yabsm.conf.

backups          Print the names of all ssh_backups and local_backups defined in
                 /etc/yabsm.conf.
END_HELP
}

                 ####################################
                 #               MAIN               #
                 ####################################

sub main {

    my $cmd = shift or die usage();

    if    ($cmd =~ /^(-h|--help)$/  ) { help(@_)                  }
    elsif ($cmd eq 'check'          ) { check_config(@_)          }
    elsif ($cmd eq 'subvols'        ) { print_subvols(@_)         }
    elsif ($cmd eq 'snaps'          ) { print_snaps(@_)           }
    elsif ($cmd eq 'ssh_backups'    ) { print_ssh_backups(@_)     }
    elsif ($cmd eq 'local_backups'  ) { print_local_backups(@_)   }
    elsif ($cmd eq 'backups'        ) { print_backups(@_)         }
    elsif ($cmd eq 'yabsm_dir'      ) { print_yabsm_dir(@_)       }
    elsif ($cmd eq 'yabsm_user_home') { print_yabsm_user_home(@_) }
    else {
        die usage();
    }

    exit 0;
}

                 ####################################
                 #            SUBROUTINES           #
                 ####################################

sub check_config {
    1 >= @_ or die usage();
    my $file = shift // '/etc/yabsm.conf';
    parse_config_or_die($file);
    say 'all good';
}

sub print_subvols {
    0 == @_ or die usage();
    my $config_ref = parse_config_or_die();
    say for all_subvols($config_ref);
}

sub print_snaps {
    0 == @_ or die usage();
    my $config_ref = parse_config_or_die();
    say for all_snaps($config_ref);
}

sub print_ssh_backups {
    0 == @_ or die usage();
    my $config_ref = parse_config_or_die();
    say for all_ssh_backups($config_ref);
}

sub print_local_backups {
    0 == @_ or die usage();
    my $config_ref = parse_config_or_die();
    say for all_local_backups($config_ref);
}

sub print_backups {
    0 == @_ or die usage();
    my $config_ref = parse_config_or_die();
    my @ssh_backups = all_ssh_backups($config_ref);
    my @local_backups = all_local_backups($config_ref);
    say for sort @ssh_backups, @local_backups;
}

sub print_yabsm_dir {
    0 == @_ or die usage();
    my $config_ref = parse_config_or_die();
    my $yabsm_dir = yabsm_dir($config_ref);
    say $yabsm_dir;
}

sub print_yabsm_user_home {
    0 == @_ or die usage();
    my $config_ref = parse_config_or_die();
    my $yabsm_user_home = yabsm_user_home($config_ref);
    say $yabsm_user_home;
}

1;
