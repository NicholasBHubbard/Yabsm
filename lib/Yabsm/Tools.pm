#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Basic tools to aid in the development of Yabsm.
#
#  See t/Yabsm/Tools.t for this modules tests.

package Yabsm::Tools;

use strict;
use warnings;
use v5.16.3;

use Log::Log4perl qw(get_logger);
use Time::Piece;
use File::Path qw(make_path);

use Exporter 'import';
our @EXPORT_OK = qw(die_arg_count
                    have_sudo_access_to_btrfs
                    have_sudo_access_to_btrfs_or_die
                    is_btrfs_dir
                    is_btrfs_dir_or_die
                    is_btrfs_subvolume
                    is_btrfs_subvolume_or_die
                    is_timeframe
                    safe_system
                    safe_make_path
                   );

our %EXPORT_TAGS = ( ALL => [ @EXPORT_OK ] );

                 ####################################
                 #            SUBROUTINES           #
                 ####################################

sub die_arg_count { # Has test

    # logconfess if $num_args is not in range $lower to $upper. Used
    # for ensuring that subroutines are passed the correct number or
    # arguments. Subs should use this subroutine using an expression
    # like '1 == @_ or die_arg_count(1, 1, @_)'.

    my $lower    = shift // get_logger->logconfess('yabsm: internal error: missing required arg');
    my $upper    = shift // get_logger->logconfess('yabsm: internal error: missing required arg');
    my $num_args = @_    // get_logger->logconfess('yabsm: internal error: missing required arg');

    ($lower, $upper) = ($upper, $lower) if $lower > $upper;

    if ($lower <= $num_args && $num_args <= $upper) {
        get_logger->logconfess("yabsm: internal error: called die_arg_count() but arg count is in range")
    }

    my $caller = ( caller(1) )[3];

    my $num_range_msg = $lower == $upper ? "$lower arg" : "$lower-$upper args";

    get_logger->logconfess("yabsm: internal error: call to '$caller' passed $num_args args but takes $num_range_msg");
}

sub have_sudo_access_to_btrfs { # No test

    # Return 1 if we can run `btrfs` with `sudo -n` and return 0
    # otherwise.

    0 == @_ or die_arg_count(0, 0, @_);

    return 0+(0 == system('sudo -n btrfs --help >/dev/null 2>&1'));
}

sub have_sudo_access_to_btrfs_or_die { # No test

    # Wrapper around have_sudo_access_to_btrfs() that logdies if it
    # returns false.

    0 == @_ or die_arg_count(0, 0, @_);

    have_sudo_access_to_btrfs() ? return 1 : get_logger->logconfess("yabsm: internal error: no sudo access rights to 'btrfs' while running as uid '$<'");
}

sub is_btrfs_dir { # No test

    # Return 1 if $dir is a directory residing on a btrfs filesystem
    # and return 0 otherwise.

    1 == @_ or die_arg_count(1, 1, @_);

    my $dir = shift;

    return 0 unless -d $dir;

    return 0+('btrfs' eq `stat -f --printf=%T '$dir' 2>/dev/null`);
}

sub is_btrfs_dir_or_die { # No test

    # Wrapper around is_btrfs_dir() that logdies if it returns false.

    1 == @_ or die_arg_count(1, 1, @_);

    my $dir = shift;

    is_btrfs_dir($dir) ? return 1 : get_logger->logdie("yabsm: error: '$dir' is not a directory residing on a btrfs filesystem")
}

sub is_btrfs_subvolume { # No test

    # Return 1 if $dir is a btrfs subvolume on this OS and return 0
    # otherwise.
    #
    # Please read the follow StackOverflow answer from a btrfs
    # maintainer (https://stackoverflow.com/a/32865333):
    #
    # A subvolume is identified by inode number 256, so you can check
    # it simply by
    #
    # if [ `stat --format=%i /path` -eq 256 ]; then ...; fi
    #
    # There's also a so called empty-subvolume, ie. if a nested
    # subvolume is snapshotted, this entity will exist in place of the
    # original subvolume. Its inode number is 2.
    #
    # For a generally reliable check whether any directory is a
    # subvolume, the filesystem type should be verified as well
    #
    # stat -f --format=%T /path

    1 == @_ or die_arg_count(1, 1, @_);

    my $dir = shift;

    return 0 unless is_btrfs_dir($dir);

    return 0+('256' eq `stat --printf=%i '$dir' 2>/dev/null`);
}

sub is_btrfs_subvolume_or_die { # No test

    # Wrapper around is_btrfs_subvolume() that logdies if it returns
    # false.

    1 == @_ or die_arg_count(1, 1, @_);

    my $dir = shift;

    is_btrfs_subvolume($dir) ? return 1 : get_logger->logdie("yabsm: error: '$dir' is not a btrfs subvolume")
}

sub is_timeframe { # No test

    # Return 1 if given a valid timeframe and return 0 otherwise.

    1 == @_ or die_arg_count(1, 1, @_);

    return shift =~ /^(5minute|hourly|daily|weekly|monthly)$/;
}

sub is_week_day { # No test

    # Return 1 if give a valid week day and return 0 otherwise.

    1 == @_ or die_arg_count(1, 1, @_);

    return shift =~ /^(monday|tuesday|wednesday|thursday|friday|saturday|sunday)$/;
}

sub safe_system { # No test

    # Wrapper around system that logdies if the system command fails.

    1 == @_ or die_arg_count(1, 1, @_);

    my $system_command = shift;

    my $status = system($system_command);

    unless (0 == $status) {
        get_logger->logdie("yabsm: error: system command $system_command exited with status $status");
    }

    return $status;
}

sub safe_make_path { # No test

    # Wrapper around File::Path::make_path() that logdies if the path
    # cannot be created.

    1 == @_ or die_arg_count(1, 1, @_);

    my $path = shift;

    -d $path        and return 1;
    make_path $path and return 1;

    # make_path sets $!
    get_logger->logdie("yabsm: error: $!\n");
}

1;
