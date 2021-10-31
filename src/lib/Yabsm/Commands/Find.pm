#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Find one or more snapshots of a subvol or backup by applying a query.
#  See the yabsm manual for a detailed explanation on queries.

package Yabsm::Commands::Find;

use strict;
use warnings;
use v5.16.3;

# located using lib::relative in yabsm.pl
use Yabsm::Base;
use Yabsm::Config;

sub die_usage {
    die "usage: yabsm find <SUBVOL> <QUERY>\n";
}

sub main {

    my $subject = shift // die_usage();
    my $query   = shift // die_usage();

    die_usage() if @_;

    my $config_ref = Yabsm::Config::read_config();

    if (not Yabsm::Base::is_subject($config_ref, $subject)) {
	die "yabsm: error: '$subject' is not a defined subvol or backup\n";
    }

    if (not Yabsm::Base::is_valid_query($query)) {
	die "yabsm: error: '$query' is not a valid query\n"
    }

    my @snapshots = Yabsm::Base::answer_query($config_ref, $subject, $query);

    say for @snapshots;

    return;
}

1;