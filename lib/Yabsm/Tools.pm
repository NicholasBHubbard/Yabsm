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
use File::Basename qw(basename);

use Exporter 'import';
our @EXPORT_OK = qw(die_arg_count
                    is_btrfs_dir
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

sub is_btrfs_dir { # No test

    # Return 1 if $dir is a directory residing on a btrfs filesystem
    # and return 0 otherwise.

    1 == @_ or die_arg_count(1, 1, @_);

    my $dir = shift;

    return 0 unless -d $dir;

    return 0+('btrfs' eq `stat -f --printf=%T '$dir'`);
}

sub is_btrfs_subvol { # No test

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
    # For a generally reliable check wheter any directory is a
    # subvolume, the filesystem type should be verified as well
    #
    # stat -f --format=%T /path

    1 == @_ or die_arg_count(1, 1, @_);

    my $dir = shift;

    return 0 unless is_btrfs_dir($dir);

    return 0+('256' eq `stat --printf=%i '$dir'`);
}

sub is_timeframe { # No test

    # Return 1 if $tframe is a valid timeframe and return 0 otherwise.

    1 == @_ or die_arg_count(1, 1, @_);

    return shift =~ /^(5minute|hourly|daily|weekly|monthly)$/;
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

sub is_snapshot_name { # Has test

    # Return 1 if passed a valid yabsm snapshot name and
    # return 0 otherwise.

    1 == @_ or die_arg_count(1, 1, @_);

    return 0 unless
      my ($yr, $mon, $day, $hr, $min) = shift =~ /^day=(\d{4})_(\d{2})_(\d{2}),time=(\d{2}):(\d{2})$/;

    return 0 unless $yr  >= 2000;
    return 0 unless $mon >= 1 && $mon <= 12;
    return 0 unless $day >= 0 && $day <= 31;
    return 0 unless $hr  >= 0 && $hr  <= 23;
    return 0 unless $min >= 0 && $min <= 59;

    return 1;
}

sub is_snapshot { # No test

    # Return 1 if $snapshot is a btrfs snapshot with a yabsm
    # snapshot name as per is_snapshot_name(), and return 0 otherwise.
    #
    # WARNING - This subroutine will return 1 as long as it is passed
    # a directory residing on a btrfs filesystem that has a name which
    # is a valid yabsm snapshot name. This does not necessarily mean
    # that it is a snapshot taken by yabsm.

    1 == @_ or die_arg_count(1, 1, @_);

    my $snapshot = shift;

    return
      is_snapshot_name(basename($snapshot)) && is_btrfs_dir($snapshot)
      ? 1
      : 0
      ;
}

sub nums_to_snapshot_name { # Has test

    # Take 5 integer arguments representing in order the year, month,
    # day, hour, and minute and return a snapshot name of the
    # corresponding time.

    5 == @_ or die_arg_count(5, 5, @_);

    my ($yr, $mon, $day, $hr, $min) = map { sprintf '%02d', $_ } @_;

    my $snapshot_name = "day=${yr}_${mon}_${day},time=$hr:$min";

    unless ( is_snapshot_name($snapshot_name) ) {
        get_logger->logconfess("yabsm: internal error: generated snapshot name with an invalid date - '$snapshot_name'");
    }

    return $snapshot_name;
}

sub current_time_snapshot_name { # Has test

    # Return a snapshot name corresponding to the current time.

    0 == @_ or die_arg_count(0, 0, @_);

    my $t = localtime();

    return nums_to_snapshot_name($t->year, $t->mon, $t->mday, $t->hour, $t->min);
}

sub snapshot_name_nums { # Has test

    # Take a snapshot name and return a list containing, in order, the
    # corresponding year, month, day, hour, and minute.

    1 == @_ or die_arg_count(1, 1, @_);

    my $snapshot_name = shift;

    unless ( is_snapshot_name($snapshot_name) ) {
        get_logger->logconfess("yabsm: internal error: passed invalid snapshot name - '$snapshot_name'");
    }

    my ($yr, $mon, $day, $hr, $min) = map { 0 + $_ } $snapshot_name =~ /^day=(\d{4})_(\d{2})_(\d{2}),time=(\d{2}):(\d{2})$/;

    return ($yr, $mon, $day, $hr, $min);
}

1;
