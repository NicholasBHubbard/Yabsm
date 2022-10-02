#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Provides functionality for querying information about the users config.

use strict;
use warnings;
use v5.16.3;

package App::Yabsm::Command::Config;

use App::Yabsm::Tools qw( :ALL );
use App::Yabsm::Config::Query qw( :ALL );
use App::Yabsm::Config::Parser qw(parse_config_or_die);
use App::Yabsm::Backup::SSH;
use App::Yabsm::Command::Daemon;

sub usage {
    arg_count_or_die(0, 0, @_);
    return <<'END_USAGE';
usage: yabsm <config|c> [--help] [check ?file] [ssh-check <SSH_BACKUP>] [ssh-key]
                        [yabsm-user-home] [yabsm_dir] [subvols] [snaps]
                        [ssh_backups] [local_backups] [backups]
END_USAGE
}

sub help {
    @_ == 0 or die usage();
    my $usage = usage();
    $usage =~ s/\s+$//;
    print <<"END_HELP";
$usage

--help                 Print this help message.

check ?file            Check ?file for errors and print their messages. If ?file
                       is omitted it defaults to /etc/yabsm.conf.

ssh-check <SSH_BACKUP> Check that backups for <SSH_BACKUP> are able to be
                       performed and if not print useful error messages.

ssh-key                Print the 'yabsm' users public SSH key.

yabsm-user-home        Print the 'yabsm' users home directory.

yabsm_dir              Print the value of yabsm_dir in /etc/yabsm.conf.

subvols                Print names of all subvols defined in /etc/yabsm.conf.

snaps                  Print names of all snaps defined in /etc/yabsm.conf.

ssh_backups            Print names of all ssh_backups defined in /etc/yabsm.conf.

local_backups          Print the of all local_backups defined in /etc/yabsm.conf.

backups                Print names of all ssh_backups and local_backups defined
                       in /etc/yabsm.conf.
END_HELP
}

                 ####################################
                 #               MAIN               #
                 ####################################

sub main {

    my $cmd = shift or die usage();

    if    ($cmd =~ /^(-h|--help)$/  ) { help(@_)                     }
    elsif ($cmd eq 'check'          ) { check_config(@_)             }
    elsif ($cmd eq 'ssh-check'      ) { check_ssh_backup(@_)         }
    elsif ($cmd eq 'ssh-key'        ) { print_yabsm_user_ssh_key(@_) }
    elsif ($cmd eq 'yabsm_user_home') { print_yabsm_user_home(@_)    }
    elsif ($cmd eq 'yabsm_dir'      ) { print_yabsm_dir(@_)          }
    elsif ($cmd eq 'subvols'        ) { print_subvols(@_)            }
    elsif ($cmd eq 'snaps'          ) { print_snaps(@_)              }
    elsif ($cmd eq 'ssh_backups'    ) { print_ssh_backups(@_)        }
    elsif ($cmd eq 'local_backups'  ) { print_local_backups(@_)      }
    elsif ($cmd eq 'backups'        ) { print_backups(@_)            }
    else {
        die usage();
    }
}

                 ####################################
                 #            SUBCOMMANDS           #
                 ####################################

sub check_config {
    @_ <= 1 or die usage();
    my $file = shift // '/etc/yabsm.conf';
    parse_config_or_die($file);
    say 'all good';
}

sub print_subvols {
    @_ == 0 or die usage();
    my $config_ref = parse_config_or_die();
    say for all_subvols($config_ref);
}

sub print_snaps {
    @_ == 0 or die usage();
    my $config_ref = parse_config_or_die();
    say for all_snaps($config_ref);
}

sub print_ssh_backups {
    @_ == 0 or die usage();
    my $config_ref = parse_config_or_die();
    say for all_ssh_backups($config_ref);
}

sub print_local_backups {
    @_ == 0 or die usage();
    my $config_ref = parse_config_or_die();
    say for all_local_backups($config_ref);
}

sub print_backups {
    @_ == 0 or die usage();
    my $config_ref = parse_config_or_die();
    my @ssh_backups = all_ssh_backups($config_ref);
    my @local_backups = all_local_backups($config_ref);
    say for sort @ssh_backups, @local_backups;
}

sub print_yabsm_dir {
    @_ == 0 or die usage();
    my $config_ref = parse_config_or_die();
    my $yabsm_dir = yabsm_dir($config_ref);
    say $yabsm_dir;
}

sub print_yabsm_user_home {
    @_ == 0 or die usage();
    my $config_ref = parse_config_or_die();
    my $yabsm_user_home = yabsm_user_home($config_ref);
    say $yabsm_user_home;
}

sub check_ssh_backup {

    # This is mostly just a wrapper around
    # &App::Yabsm::Backup::SSH::check_ssh_backup_config_or_die.

    @_ == 1 or die usage();

    die 'yabsm: error: permission denied'."\n" unless i_am_root();

    my $ssh_backup = shift;

    my $config_ref = parse_config_or_die();

    unless (ssh_backup_exists($ssh_backup, $config_ref)) {
        die "yabsm: error: no such ssh_backup named '$ssh_backup'\n";
    }

    unless (App::Yabsm::Command::Daemon::yabsm_user_exists()) {
        die q(yabsm: error: cannot find user named 'yabsm')."\n";
    }

    unless (App::Yabsm::Command::Daemon::yabsm_group_exists()) {
        die q(yabsm: error: cannot find group named 'yabsm')."\n";
    }

    POSIX::setgid(scalar(getgrnam 'yabsm'));
    POSIX::setuid(scalar(getpwnam 'yabsm'));

    App::Yabsm::Backup::SSH::check_ssh_backup_config_or_die(undef, $ssh_backup, $config_ref);

    say 'all good';
}

sub print_yabsm_user_ssh_key {

    # Print the yabsm users public key to STDOUT.

    @_ == 0 or die usage();

    die 'yabsm: error: permission denied'."\n" unless i_am_root();

    my $config_ref = parse_config_or_die();

    my $yabsm_user_ssh_dir = yabsm_user_home($config_ref) . '/.ssh';

    my $priv_key = "$yabsm_user_ssh_dir/id_ed25519";
    my $pub_key  = "$yabsm_user_ssh_dir/id_ed25519.pub";

    unless (-f $priv_key) {
        die "yabsm: error: could not find user 'yabsm' users SSH private key '$priv_key'\n";
    }

    unless (-f $pub_key) {
        die "yabsm: error: could not find user 'yabsm' users SSH public key '$pub_key'\n";
    }

    open my $fh, '<', $pub_key
      or die "yabsm: internal error: could not open '$pub_key' for reading\n";

    print <$fh>;

    close $fh
}

1;
