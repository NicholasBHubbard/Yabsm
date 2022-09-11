#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Provides functionality for testing and configuring an SSH server for yabsm
#  backups.

use strict;
use warnings;
use v5.16.3;

package Yabsm::Command::SSH;

use Yabsm::Tools qw( :ALL );
use Yabsm::Config::Query qw ( :ALL );
use Yabsm::Config::Parser qw(parse_config_or_die);
use Yabsm::Backup::SSH;
use Yabsm::Command::Daemon;

use Net::OpenSSH;

use Carp qw(confess);
use POSIX ();

sub usage {
    arg_count_or_die(0, 0, @_);
    return 'usage: yabsm ssh [--help] [check <SSH_BACKUP>] [print-ssh-key]'."\n";
}

                 ####################################
                 #               MAIN               #
                 ####################################

sub main {

    my $cmd = shift;

    if    ($cmd =~ /^$(-h|--help)/) { help(@_)      }
    elsif ($cmd eq 'check'        ) { check(@_)     }
    elsif ($cmd eq 'print-key'    ) { print_key(@_) }
    else {
        die usage();
    }
}

                 ####################################
                 #              COMMANDS            #
                 ####################################

sub help {
    0 == @_ or die usage();
    my $usage = usage();
    $usage =~ s/\s+$//;
    print <<"END_HELP";
$usage

--help              Print this help message.

check <ssh_backup>  Check that <ssh_backup> can be performed and print useful
                    error messages if not.

print-ssh-key       Print the yabsm users public SSH key.
END_HELP
}

sub check {

    # This is really just a wrapper around
    # &Yabsm::Backup::SSH::check_ssh_backup_config_or_die.

    1 == @_ or die usage();

    die 'yabsm: error: permission denied'."\n" unless i_am_root();

    my $ssh_backup = shift;

    my $config_ref = parse_config_or_die();

    unless (ssh_backup_exists($ssh_backup, $config_ref)) {
        die "yabsm: error: no such ssh_backup named '$ssh_backup'\n";
    }

    unless (Yabsm::Command::Daemon::yabsm_user_exists()) {
        die q(yabsm: error: cannot find user named 'yabsm' on this OS)."\n";
    }

    POSIX::setuid(scalar(getpwnam 'yabsm'));

    Yabsm::Backup::SSH::check_ssh_backup_config_or_die(undef, $ssh_backup, $config_ref);

    say 'all good';
}

sub print_key {

    # Print the yabsm users public key to STDOUT.

    0 == @_ or die usage();

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

    open my $fh, '<', $pub_key or confess "yabsm: internal error: could not open '$pub_key' for reading";

    print <$fh>;

    close $fh
}

1;
