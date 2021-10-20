#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Find one or more snapshots of a subvol or backup by applying a query.
#  See the yabsm manual for a detailed explanation on queries.

package App::Commands::Find;

use strict;
use warnings;
use 5.010;

use App::Base;
use App::Yabsmrc;

sub die_usage {
    die "usage: yabsm find <SUBVOL> <QUERY>\n";
}

sub main {

    my $subject = shift // die_usage();
    my $query   = shift // die_usage();

    if (@_) { die_usage() }

    my $config_ref = Yabsmrc::read_config();

    if (not App::Base::is_subject($config_ref, $subject)) {
	die "error: '$subject' is not a defined subvol or backup\n";
    }

    if (not App::Base::is_valid_query($query)) {
	die "error: '$query' is not a valid query\n"
    }

    my @snapshots = App::Base::answer_query($config_ref, $subject, $query);

    say for @snapshots;

    return;
}

1;
