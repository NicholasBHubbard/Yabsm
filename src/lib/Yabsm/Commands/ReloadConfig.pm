#  Author:  Nicholas Hubbard
#  WWW:     https://github.com/NicholasBHubbard/yabsm
#  License: MIT

#  Ask yabsmd to re-read /etc/yabsm.conf and construct a new config.

package Yabsm::Commands::ReloadConfig;

use strict;
use warnings;
use v5.16.3;

use Carp;
use IO::Socket::UNIX;

use lib::relative '../..';
use Yabsm::Base;
use Yabsm::Config;
use Yabsm::Commands::CheckConfig;

sub die_usage {
    die "usage: yabsm reconfig\n"
}

sub main {

    die "yabsm: error: permission denied\n" if $<;

    die_usage() if @_;

    Yabsm::Commands::CheckConfig();

    my $client = IO::Socket::UNIX->new(
        Type     => SOCK_STREAM,
        Peer     => '/run/yabsmd/yabsmd.socket',
        Blocking => 1,
        Timeout  => 1
    ) or confess "yabsmd: internal error: could not create UNIX socket - $@";

    $client->send("RELOAD_CONFIG\n");

    if (<$client>) {
        say 'all good';
    }
    else {
        say 'yabsmd: error: could not reload config';
    }

    close $client;

    return;
}

1;
