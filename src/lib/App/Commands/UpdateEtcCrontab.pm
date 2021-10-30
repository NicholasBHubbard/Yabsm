#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Write cronjobs that are generated by reading /etc/yabsm.conf to
#  /etc/crontab.

package App::Commands::UpdateEtcCrontab;

use strict;
use warnings;
use v5.16.3;

# located using lib::relative in yabsm.pl
use App::Base;
use App::Config;

use File::Copy 'move';

sub die_usage {
    die "usage: yabsm update-crontab\n";
}

sub main {

    die "error: permission denied\n" if $<;

    die_usage() if @_;

    my $config_ref = App::Config::read_config();

    open (my $etc_crontab_fh, '<', '/etc/crontab')
      or die "error: failed to open file '/etc/crontab'\n";

    open (my $tmp_fh, '>', '/tmp/yabsm-update-tmp')
      or die "error: failed to open tmp file '/tmp/yabsm-update-tmp'\n";

    # rewrite non-yabsm data to the tmp file
    while (<$etc_crontab_fh>) {

	s/\s+$//; # strip trailing whitespace

	next if /yabsm/; # don't copy the old yabsm cronjobs

	say $tmp_fh $_;
    }

    # append the cronjob strings to $tmp file.
    my @cron_strings = App::Base::generate_cron_strings($config_ref);
    say $tmp_fh $_ for @cron_strings;

    # crontab files must end with a blank line.
    say $tmp_fh, ''; 

    close $etc_crontab_fh;
    close $tmp_fh;

    move '/tmp/yabsm-update-tmp', '/etc/crontab';

    return;
} 

1;
