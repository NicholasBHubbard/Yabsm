#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Miscellaneous tools to aid in the development of Yabsm.
#
#  See t/Tools.t for this modules tests.

use strict;
use warnings;
use v5.16.3;

package App::Yabsm::Tools;

use Time::Piece;
use Feature::Compat::Try;
use Carp qw(confess);
use File::Path qw(make_path);
use File::Basename qw(dirname);

use Exporter qw(import);
our @EXPORT_OK = qw(have_prerequisites
                    have_prerequisites_or_die
                    arg_count_or_die
                    with_error_catch_log
                    have_sudo_access_to_btrfs
                    have_sudo_access_to_btrfs_or_die
                    is_btrfs_dir
                    is_btrfs_dir_or_die
                    is_btrfs_subvolume
                    is_btrfs_subvolume_or_die
                    nums_denote_valid_date
                    nums_denote_valid_date_or_die
                    system_or_die
                    make_path_or_die
                    i_am_root
                    i_am_root_or_die
                   );
our %EXPORT_TAGS = ( ALL => [ @EXPORT_OK ] );

                 ####################################
                 #            SUBROUTINES           #
                 ####################################

sub have_prerequisites {

    # Return 1 if we are running on a Linux OS and have sudo, OpenSSH, and
    # btrfs-progs installed.

    return 0 unless $^O =~ /linux/i;
    return 0 unless 0 == system('which btrfs >/dev/null 2>&1');
    return 0 unless `ssh -V 2>&1` =~ /^OpenSSH/;
    return 0 unless 0 == system('which sudo >/dev/null 2>&1');

    return 1;
}

sub have_prerequisites_or_die {

    # Like &have_prerequisites except die if the prerequisites are not met.

    unless ($^O =~ /linux/i) {
        die "yabsm: internal error: not a Linux OS, this is a '$^O' OS\n";
    }

    unless (0 == system('which btrfs >/dev/null 2>&1')) {
        die 'yabsm: internal error: btrfs-progs not installed'."\n";
    }

    unless (`ssh -V 2>&1` =~ /^OpenSSH/) {
        die 'yabsm: internal error: OpenSSH not installed'."\n";
    }

    unless (0 == system('which sudo >/dev/null 2>&1')) {
        die 'yabsm: internal error: sudo not installed'."\n";
    }

    return 1;
}

sub arg_count_or_die {

    # Carp::Confess unless $num_args is in range $lower-$upper. If $lower equals
    # '_' then it is assumed to be 0 and if $upper equals '_' it is assumed to
    # be infinity.

    my $lower    = shift;
    my $upper    = shift;
    my $num_args = scalar @_;

    $lower = 0 if $lower eq '_';

    my $lower_ok = $lower <= $num_args;
    my $upper_ok = $upper eq '_' ? 1 : $upper >= $num_args;

    unless ($lower_ok && $upper_ok) {
        my $caller    = ( caller(1) )[3];
        my $error_msg = "yabsm: internal error: called '$caller' with $num_args args but it expects";
        my $range_msg;
        if    ($upper eq '_')    { $range_msg = "at least $lower args" }
        elsif ($lower == $upper) { $range_msg = "$lower args"          }
        else                     { $range_msg = "$lower-$upper args"   }
        confess("$error_msg $range_msg");
    }

    return 1;
}

sub with_error_catch_log {

    # Call $sub with @args within a Feature::Compat::Try try/catch block to catch
    # any exception and log it to /var/log/yabsm instead of killing the program.

    my $sub  = shift;
    my @args = @_;

    try {
        $sub->(@args);
    }
    catch ($e) {
        if (-f '/var/log/yabsm' && open(my $fh, '>>', '/var/log/yabsm')) {
            $e =~ s/^\s+|\s+$//g;
            my $t = localtime();
            my ($yr, $mon, $day, $hr, $min) = map { sprintf '%02d', $_ } $t->year, $t->mon, $t->mday, $t->hour, $t->min;
            say $fh "[${yr}_${mon}_${day}_$hr:$min]: $e";
            close $fh;
        }
    }
}

sub have_sudo_access_to_btrfs {

    # Return 1 if we can run 'btrfs' with 'sudo -n' and return 0 otherwise.

    arg_count_or_die(0, 0, @_);

    return 0+(0 == system('sudo -n btrfs --help >/dev/null 2>&1'));
}

sub have_sudo_access_to_btrfs_or_die {

    # Wrapper around have_sudo_access_to_btrfs() that Carp::Confess's if it
    # returns false.

    arg_count_or_die(0, 0, @_);

    my $username = getpwuid $<;

    have_sudo_access_to_btrfs() ? return 1 : die("yabsm: internal error: no sudo access rights to 'btrfs' while running as user '$username'");
}

sub is_btrfs_dir {

    # Return 1 if $dir is a directory residing on a btrfs subvolume
    # and return 0 otherwise.

    arg_count_or_die(1, 1, @_);

    my $dir = shift;

    return 0 unless -d $dir;

    return 0+(0 == system("btrfs property list '$dir' >/dev/null 2>&1"));
}

sub is_btrfs_dir_or_die {

    # Wrapper around is_btrfs_dir() that Carp::Confess's if it returns false.

    arg_count_or_die(1, 1, @_);

    my $dir = shift;

    is_btrfs_dir($dir) ? return 1 : die("yabsm: internal error: '$dir' is not a directory residing on a btrfs filesystem\n")
}

sub is_btrfs_subvolume {

    # Return 1 if $dir is a btrfs subvolume on this OS and return 0
    # otherwise.
    #
    # A btrfs subvolume is identified by inode number 256

    arg_count_or_die(1, 1, @_);

    my $dir = shift;

    return 0 unless is_btrfs_dir($dir);

    my $inode_num = (split /\s+/, `ls -di '$dir' 2>/dev/null`, 2)[0];

    return 0+(256 == $inode_num);
}

sub is_btrfs_subvolume_or_die {

    # Wrapper around is_btrfs_subvolume() that Carp::Confess's if it returns
    # false.

    arg_count_or_die(1, 1, @_);

    my $dir = shift;

    is_btrfs_subvolume($dir) ? return 1 : die("yabsm: internal error: '$dir' is not a btrfs subvolume")
}

sub nums_denote_valid_date {

    # Return 1 if passed a year, month, month-day, hour, and minute
    # that denote a valid date and return 0 otherwise.

    arg_count_or_die(5, 5, @_);

    my ($yr, $mon, $day, $hr, $min) = @_;

    return 0 unless $yr  >= 1;
    return 0 unless $mon >= 1 && $mon <= 12;
    return 0 unless $hr  >= 0 && $hr  <= 23;
    return 0 unless $min >= 0 && $min <= 59;

    # month days are a bit more complicated to figure out

    if ($mon == 1 || $mon == 3 || $mon == 5 || $mon == 7 || $mon == 8 || $mon == 10 || $mon == 12) {
        return 0 unless $day >= 1 && $day <= 31;
    }
    elsif ($mon == 4 || $mon == 6 || $mon == 9 || $mon == 11) {
        return 0 unless $day >= 1 && $day <= 30;
    }
    else { # February
        my $is_leap_yr;

        if    ($yr % 400 == 0) { $is_leap_yr = 1 }
        elsif ($yr % 100 == 0) { $is_leap_yr = 0 }
        elsif ($yr % 4   == 0) { $is_leap_yr = 1 }
        else                   { $is_leap_yr = 0 }

        my $upper = $is_leap_yr ? 29 : 28;

        return 0 unless $day >= 1 && $day <= $upper;
    }

    return 1;
}

sub nums_denote_valid_date_or_die {

    # Wrapper around &nums_denote_valid_date that Carp::Confess's if it
    # returns false.

    arg_count_or_die(5, 5, @_);

    unless ( nums_denote_valid_date(@_) ) {
        my ($yr, $mon, $day, $hr, $min) = @_;
        confess("yabsm: internal error: '${yr}_${mon}_${day}_$hr:$min' does not denote a valid yr_mon_day_hr:min date");
    }

    return 1;
}

sub system_or_die {

    # Wrapper around system that Carp::Confess's if the system command exits
    # with a non-zero status. Redirects STDOUT and STDERR to /dev/null.

    open my $NULLFD, '>', '/dev/null';
    open my $OLD_STDOUT, '>&', STDOUT;
    open my $OLD_STDERR, '>&', STDERR;
    open STDOUT, '>&', $NULLFD;
    open STDERR, '>&', $NULLFD;

    my $status = system @_;

    open STDOUT, '>&', $OLD_STDOUT;
    open STDERR, '>&', $OLD_STDERR;
    close $NULLFD;
    close $OLD_STDOUT;
    close $OLD_STDERR;

    unless (0 == $status) {
        confess("yabsm: internal error: system command '@_' exited with non-zero status '$status'");
    }

    return 1;
}

sub make_path_or_die {

    # Wrapper around File::Path::make_path() that Carp::Confess's if the path
    # cannot be created. The UID and GID of the $path will be set to that of the
    # deepest existing sub-directory in $path.

    my $path = shift;

    $path =~ /^\//
      or die "yabsm: internal error: '$path' is not an absolute path starting with '/'";

    my $dir = $path;

    until (-d $dir) {
        $dir = dirname($dir);
    }

    my ($uid, $gid) = (stat $dir)[4,5];

    -d $path and return 1;

    make_path($path, {uid => $uid, group => $gid}) and return 1;

    my $username = getpwuid $<;

    die "yabsm: error: could not create path '$path' while running as user '$username'\n";
}

sub i_am_root {

    # Return 1 if current user is root and return 0 otherwise.

    return 0+(0 == $<);
}

sub i_am_root_or_die {

    # Die unless running as the root user.

    arg_count_or_die(0, 0, @_);

    unless (i_am_root()) {
        my $username = getpwuid $<;
        confess("yabsm: internal error: not running as root - running as '$username'");
    }

    return 1;
}

1;
