#!/usr/bin/env perl

use strict;
use warnings;
use v5.020;


use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use Test::More;
use Test::Git;

use Path::Tiny;
use Proc::Background;
use File::pushd;

use GitP2P::Tests qw/create_simple_dir_layout create_simple_config_layout/;


has_git();


plan tests => 1;


my $test_dir = "11-test-clone";

my $relay;
my @daemons;

# Start relay
{
    $relay = Proc::Background->new("perl",
        "$Bin/../gitp2p-relay.pl", "$Bin/../etc/gitp2p-config");
    sleep 1; # wait for the relay to init
}

# Create master repo
{
    my $repo_dir = create_simple_dir_layout($test_dir, "peer1", "clone-simple");
    create_simple_config_layout($repo_dir, 47001, 0);


    # commit 1
    Git::Repository->run(init => $repo_dir);
    my $master_repo = Git::Repository->new(work_tree => $repo_dir);

    path("$repo_dir/test.txt")->spew("hello, there!");

    $master_repo->run("add", "test.txt");
    $master_repo->run("commit", "-m", "simple commit");


    push @daemons, Proc::Background->new("perl", 
        "$Bin/../gitp2pd.pl", "-X", "$repo_dir/../etc", "--add");
    sleep 1; # wait for the daemon to init
}


# Create peer2 dir and try cloning
{
    my $repo_dir = create_simple_dir_layout($test_dir, "peer2", "clone-simple");
    create_simple_config_layout($repo_dir, 47002, 0);


    my $dir = pushd "$repo_dir/../";
    my $clone_cmd = Git::Repository->command("clone", 
        'gitp2p://cpi.cecko@gmail.com/clone-simple');

    my $stderr = $clone_cmd->stderr();
    while (<$stderr>) {
        print "$_";
    }
    $clone_cmd->close();

    ok($clone_cmd->exit() == 0, "Cloning repo");
}


END {
    $relay->die;
    map { $_->die } @daemons;

    $? = 0;
}
