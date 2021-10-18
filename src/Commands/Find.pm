#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Find one or more snapshots of a subvol or backup by applying a query.
#  See the yabsm manual for a detailed explanation on queries.

package Commands::Find;

use strict;
use warnings;
use 5.010;

use lib '../lib';
use Base;
use Yabsmrc;

sub die_usage {
    say 'Usage: yabsm find <SUBVOL> <QUERY>';
    exit 1;
}

sub main {

    my $subject = shift // die_usage();
    my $query   = shift // die_usage();

    if (@_) { die_usage() }

    my $config_ref = Yabsmrc::read_config();

    if (not Base::is_subject($config_ref, $subject)) {
	die "yabsm: error: '$subject' is not a defined subvol or backup\n";
    }

    if (not Base::is_valid_query($query)) {
	die "yabsm: error: '$query' is not a valid query\n"
    }

    my @snapshots = Base::answer_query($config_ref, $subject, $query);

    say for @snapshots;

    return;
}

1;
