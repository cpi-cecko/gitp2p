#!/usr/bin/env perl

#
# This tests the following layout:
#
#   owner  peer1  peer2  peer3  peer4  peer5  |  cloner
#  
# 7   0      0                                         
#     |      |                                         
# 6   0      0                           0             
#     |      |                           |             
# 5   0      0             0             0             
#     |      |             |             |             
# 4   0      0      0      0             0             
#     |      |      |      |             |             
# 3   0      0      0      0      0      0             
#     |      |      |      |      |      |             
# 2   0      0      0      0      0      0             
#     |      |      |      |      |      |             
# 1   0      0      0      0      0      0             
#
# Each peer does a path-based clone from the owner and then does 
# `git reset --hard HEAD'.
#

use strict;
use warnings;
use v5.020;


use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use Test::More;
use Test::Git;

use Path::Tiny;
use JSON::XS;
use Proc::Background;
use File::pushd;

use GitP2P::Tests qw/create_simple_dir_layout create_simple_config_layout init_cloned_repo/;


has_git();


my $test_dir = "12-test-clone-many-peers";

my $relay;
my @daemons;

# Start the relay
{
    $relay = Proc::Background->new("perl",
        "$Bin/../gitp2p-relay.pl", "$Bin/../etc/gitp2p-config");
    sleep 1; # wait for the relay to init
}

# Create master repo
{
    my $repo_dir = create_simple_dir_layout($test_dir, "master", "clone-complex");
    create_simple_config_layout($repo_dir, 47001, 0);


    # commit 1
    Git::Repository->run(init => $repo_dir);
    my $master_repo = Git::Repository->new(work_tree => $repo_dir);

    path("$repo_dir/config")->spew("Having data is my biggest issue\n");

    $master_repo->run("add", "config");
    $master_repo->run("commit", "-m", "creates config");

    # commit 2
    path("$repo_dir/config")->append("But then, what's life without data?\n");
    path("$repo_dir/process.R")->spew("data <- read.csv(\"much_data\")\n");

    $master_repo->run("add", "config");
    $master_repo->run("add", "process.R");
    $master_repo->run("commit", "-m", "starts processing some data");

    # commit 3
    path("$repo_dir/process.R")->append("# Data must be inspected\nsummary(data)\n");
    
    $master_repo->run("add", "process.R");
    $master_repo->run("commit", "-m", "inspects some data");

    # commit 4
    path("$repo_dir/config")->append("Life without data is mindless.\n");
    path("$repo_dir/tasks.txt")->spew("1. Figure out what to do with data\n");

    $master_repo->run("add", "config");
    $master_repo->run("add", "tasks.txt");
    $master_repo->run("commit", "-m", "adds tasks");

    # commit 5
    path("$repo_dir/process.R")->append("\n# Data must be interpreted\nhead(data, n=10)\n");

    $master_repo->run("add", "process.R");
    $master_repo->run("commit", "-m", "interprets some data");

    # commit 6
    path("$repo_dir/tasks.txt")->append("2. Apply data\n");

    $master_repo->run("add", "tasks.txt");
    $master_repo->run("commit", "-m", "adds another task");
    
    # commit 7
    path("$repo_dir/config")->append("But data without context? It's a waste of time.\n");
    path("$repo_dir/process.R")->append("data = NULL\n");

    $master_repo->run("add", "config");
    $master_repo->run("add", "process.R");
    $master_repo->run("commit", "-m", "deletes data");


    $master_repo->run("config", "--local", "--add", "user.email", 'master@test.git');

    push @daemons, Proc::Background->new("perl",
        "$Bin/../gitp2pd.pl", "-X", "$repo_dir/../etc", "--add");
    sleep 1; # Wait for the daemon to init

    say "Master repo created";
}

# Create peer1
{
    my $repo_dir = init_cloned_repo(
          clone_from => '../master/clone-complex'
        , test_dir => $test_dir
        , user_dir => "peer1"
        , repo_name => "clone-complex"
        , daemon_port => 47002
        , debug_sleep => 0
    );

    my $peer1_repo = Git::Repository->new(work_tree => $repo_dir);
    $peer1_repo->run("config", "--local", "--add", "user.email", 'peer1@test.git');

    push @daemons, Proc::Background->new("perl",
        "$Bin/../gitp2pd.pl", "-X", "$repo_dir/../etc", "--add");
    sleep 1; # Wait for the daemon to init
}

# Create peer2
{
    my $repo_dir = init_cloned_repo(
          clone_from => '../master/clone-complex'
        , test_dir => $test_dir
        , user_dir => "peer2"
        , repo_name => "clone-complex"
        , daemon_port => 47003
        , debug_sleep => 0
    );

    my $peer2_repo = Git::Repository->new(work_tree => $repo_dir);
    $peer2_repo->run("reset", "--hard", "HEAD~3");

    $peer2_repo->run("config", "--local", "--add", "user.email", 'peer2@test.git');

    push @daemons, Proc::Background->new("perl",
        "$Bin/../gitp2pd.pl", "-X", "$repo_dir/../etc", "--add");
    sleep 1; # Wait for the daemon to init
}

# Create peer3
{
    my $repo_dir = init_cloned_repo(
          clone_from => '../master/clone-complex'
        , test_dir => $test_dir
        , user_dir => "peer3"
        , repo_name => "clone-complex"
        , daemon_port => 47004
        , debug_sleep => 0
    );

    my $peer3_repo = Git::Repository->new(work_tree => $repo_dir);
    $peer3_repo->run("reset", "--hard", "HEAD~2");

    $peer3_repo->run("config", "--local", "--add", "user.email", 'peer3@test.git');

    push @daemons, Proc::Background->new("perl",
        "$Bin/../gitp2pd.pl", "-X", "$repo_dir/../etc", "--add");
    sleep 1; # Wait for the daemon to init
}

# Create peer4
{
    my $repo_dir = init_cloned_repo(
          clone_from => '../master/clone-complex'
        , test_dir => $test_dir
        , user_dir => "peer4"
        , repo_name => "clone-complex"
        , daemon_port => 47005
        , debug_sleep => 0
    );

    my $peer4_repo = Git::Repository->new(work_tree => $repo_dir);
    $peer4_repo->run("reset", "--hard", "HEAD~4");

    $peer4_repo->run("config", "--local", "--add", "user.email", 'peer4@test.git');

    push @daemons, Proc::Background->new("perl",
        "$Bin/../gitp2pd.pl", "-X", "$repo_dir/../etc", "--add");
    sleep 1; # Wait for the daemon to init
}

# Create peer5
{
    my $repo_dir = init_cloned_repo(
          clone_from => '../master/clone-complex'
        , test_dir => $test_dir
        , user_dir => "peer5"
        , repo_name => "clone-complex"
        , daemon_port => 47006
        , debug_sleep => 0
    );

    my $peer5_repo = Git::Repository->new(work_tree => $repo_dir);
    $peer5_repo->run("reset", "--hard", "HEAD~1");

    $peer5_repo->run("config", "--local", "--add", "user.email", 'peer5@test.git');

    push @daemons, Proc::Background->new("perl",
        "$Bin/../gitp2pd.pl", "-X", "$repo_dir/../etc", "--add");
    sleep 1; # Wait for the daemon to init
}


END {
    $relay->die;
    map { $_->die } @daemons;

    $? = 0;
}
