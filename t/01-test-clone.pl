#!/usr/bin/env perl

use strict;
use warnings;
use v5.020;


use FindBin qw/$Bin/;

use Test::More;
use Test::Git;

use Path::Tiny;
use JSON::XS;
use Proc::Background;
use File::pushd;


has_git();


plan tests => 2;


my $relay;
my $daemon_peer1;

# Start relay
{
    # TODO: Make the relay log to a file
    $relay = Proc::Background->new("perl",
        "$Bin/../gitp2p-relay.pl", "$Bin/../gitp2p-config");
}

# Create master repo
{
    my $simple_repo_dir = "test-users/peer1/clone-simple/";
    path($simple_repo_dir)->mkpath;

    Git::Repository->run(init => $simple_repo_dir);
    my $master_repo = Git::Repository->new(work_tree => $simple_repo_dir);

    my $test = path("$simple_repo_dir/test.txt");
    $test->spew("hello, there!");

    $master_repo->run("add", "test.txt");
    my $commit_cmd = $master_repo->command("commit", "-m", "simple commit");
    $commit_cmd->close();

    ok($commit_cmd->exit() == 0, "Initting repo");

    # Create gitp2p-config
    my $gitp2p_cfg_cnts = JSON::XS->new->pretty(1)->encode({
            relays => { localhost => "localhost:12500" },
            preferred_relay => "localhost",
            port_daemon => 47001,
            port_relay => 12500,
            port_hugz => 12501,
            peers_file => "/media/files/PROJECTS/gitp2p/peers"
        });
    path("$simple_repo_dir/../gitp2p-config")->touch->spew($gitp2p_cfg_cnts);

    # Create daemon cfg
    my $daemon_cfg_cnts = JSON::XS->new->pretty(1)->encode({
            repos => { "clone-simple" => "$Bin/$simple_repo_dir/.git/" },
            port => 47001,
            debug_sleep => 0
        });
    my $daemon_cfg = path("$simple_repo_dir/../daemon-cfg")->touch;
    $daemon_cfg->spew($daemon_cfg_cnts);

    # Spawn daemon
    $daemon_peer1 = Proc::Background->new("perl", 
        "$Bin/../gitp2pd.pl", "$Bin/$simple_repo_dir/../daemon-cfg");
}


# Create peer2 dir and try cloning
{
    my $simple_repo_peer2 = "test-users/peer2/clone-simple/";
    path($simple_repo_peer2)->mkpath;

    # Create gitp2p-config
    my $gitp2p_cfg_cnts = JSON::XS->new->pretty(1)->encode({
            relays => { localhost => "localhost:12500" },
            preferred_relay => "localhost",
            port_daemon => 47002,
            port_relay => 12500,
            port_hugz => 12501,
            peers_file => "/media/files/PROJECTS/gitp2p/peers"
        });
    path("$simple_repo_peer2/../gitp2p-config")->touch->spew($gitp2p_cfg_cnts);

    # Create daemon config
    my $daemon_cfg_cnts = JSON::XS->new->pretty(1)->encode({
            repos => { "clone-simple" => "$Bin/$simple_repo_peer2/.git/" },
            port => 47002,
            debug_sleep => 0
        });
    path("$simple_repo_peer2/../daemon-cfg")->touch->spew($daemon_cfg_cnts);

    # Clone the repo
    # my $daemon_started = `netstat -an | grep LISTEN`;
    # print "\n======\n$daemon_started======\n";
    # print "Alive: " . $daemon_peer1->alive . "\n";
    # my $daemon_status = `./../gitp2pd.pl status`;
    # print "\n=========\n$daemon_status========\n";

    my $dir = pushd "$simple_repo_peer2/../";
    my $clone_cmd = Git::Repository->command("clone", 
        'gitp2p://cpi.cecko@gmail.com/clone-simple');

    my $stderr = $clone_cmd->stderr();
    while (<$stderr>) {
        print "$_";
    }
    $clone_cmd->close();

    ok($clone_cmd->exit() == 0, "Cloning repo");
}

$relay->die;
$daemon_peer1->die;


# path($simple_repo_dir)->remove_tree;
# TODO: Add cleanup
