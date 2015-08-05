#!/usr/bin/env perl

use strict;
use warnings;
use v5.020;


use FindBin;
use lib "$FindBin::Bin/lib";

use Path::Tiny;
use Method::Signatures;
use IO::Async::Stream;
use IO::Async::Loop;
use List::MoreUtils qw/indexes/;
use JSON::XS;
use Log::Log4perl;
use File::pushd;

use GitP2P::Proto::Daemon;
use GitP2P::Proto::Relay;
use GitP2P::Core::Common;
use GitP2P::Core::Finder;

use App::Daemon qw/daemonize/;
daemonize();


Log::Log4perl::init_and_watch("$FindBin::Bin/gitp2p-log.conf", 'HUP');
my $log = Log::Log4perl->get_logger("gitp2pd");  
$log->info("RUNNING");

my %operations = ( "list"           => \&on_list,
                 , "fetch_pkt_line" => \&on_fetch,
                 , "hugz"           => \&on_hugz,
                 );

die "Usage: ./gitp2pd <cfg_path> [--add]"
    if scalar @ARGV == 0;
my $cfg_file = $ARGV[0];
my $is_add = 1 if defined $ARGV[1]; # Should we announce ourselves to the relay on startup

$log->logdie("Config doesn't exist") unless path($cfg_file)->exists;

my $cfg = JSON::XS->new->ascii->decode(path($cfg_file)->slurp);


if ($is_add) {
    # Hickaty hack
    my $dir = pushd $cfg->{repos}->{"clone-simple"} . "../";

    # Add daemon to relay
    my $user_id = qx(git config --get user.email);
    chomp $user_id;
    # We use only the ref to which our HEAD points for testing purposes.
    # A proper implementation should query all available refs and send them to
    # the relay.
    my $last_ref_sha = qx(git rev-list HEAD --max-count=1);
    chomp $last_ref_sha;
    my $last_ref_name = qx(git symbolic-ref HEAD);
    chomp $last_ref_name;
    my $last_ref = $last_ref_name . "?" . $last_ref_sha;
    $log->info("Dir: '$dir'");
    $log->info("Last ref: '$last_ref'");

    my $cfg = JSON::XS->new->ascii->decode(path("$FindBin::Bin/gitp2p-config")->slurp);
    my $s = GitP2P::Core::Finder::connect_to_relay(\$cfg, $cfg->{port_daemon});
    my $relay_add_msg = GitP2P::Proto::Relay::build("add-peer",
        ["clone-simple", $user_id, $last_ref]);
    $s->send($relay_add_msg);

    my $resp = <$s>;
    chomp $resp;

    close $s;
}


# Lists refs for a given repo
func on_list(Object $sender, GitP2P::Proto::Daemon $msg) {
    my ($repo, @refs) = split /\n/, $msg->op_data;

    $log->logdie("Invalid repo line format: '$repo'")
        if $repo !~ /^repo \S+$/;
    my (undef, $repo_name) = split / /, $repo;

    $log->info("Processing refs: [@refs]");
    my $dir = pushd $cfg->{repos}->{$repo_name} . "../";

    for my $ref_line (@refs) {
        my ($ref_name, $ref_shas) = split / /, $ref_line;
        # We love inner loops!
        my $add = 1;
        # Determine whether we have all the listed refs.
        # If so, then there's a chance that we have a newer ref.
        for (split /,/, $ref_shas) {
            $log->info("Split ref_shas");
            my $found = qx(git cat-file -e $_ 2>/dev/null && echo "true" || echo "false");
            if ($found eq "false") {
                $add = 0;
                last;
            }
        }
        # TODO: Don't add if the ref is already in the list
        if ($add) {
            my $latest_ref = qx(git rev-list $ref_name --max-count=1);
            $log->info("Sending latest ref: '$latest_ref'");

            my $list_ack_msg = GitP2P::Proto::Daemon::build_comm(
                "list_ack", [$ref_name, $latest_ref]);
            $sender->write($list_ack_msg);
        }
    }

    $log->info("Sending end");
    $sender->write("end\n");
}

# Returns wanted object by client
func on_fetch(Object $sender, GitP2P::Proto::Daemon $msg) { 
    my $objects = $msg->op_data;

    my ($repo, $id, @rest) = split /\n/, $objects;

    die "Invalid repo line format: '$repo'"
        if $repo !~ /^repo \S+ \S+$/;
    my (undef, $repo_name, $repo_owner) = split / /, $repo;

    die "Invalid id line format: '$id'"
        if $id !~ /^id \d+ \d+$/;
    my (undef, $beg, $step) = split / /, $id;

    my @wants;
    my @haves;
    for my $pkt_line (@rest) {
        if ($pkt_line =~ /^(\w+)\s([a-f0-9]{40})\n?$/) {
            $1 eq "want"
                and push @wants, $2;
            $1 eq "have"
                and push @haves, $2;
        }
    }

    my $repo_path = $cfg->{repos}->{$repo_name} . "/../";
    # TODO: List objects based on the refs that `wants' contains
    my @objects = GitP2P::Core::Common::list_objects($repo_path);
    for my $have (@haves) { # Hacking my way through life
        @objects = grep { $_ !~ /^$have/ } @objects;
    }

    # Get every $step-th object beggining from $beg
    @objects = @objects[map { $_ += $beg } indexes { $_ % $step == 0 } (0..$#objects)];
    @objects = grep { defined $_ } @objects;
    $log->info("objects \n" . join "", @objects);

    my $config_file = $cfg->{repos}->{$repo_name} . "/config";
    my $user_id = qx(git config --file $config_file --get user.email);

    my $pack_data = GitP2P::Core::Common::create_pack_from_list(\@objects, $repo_path);
    $log->info("pack_data: '$pack_data'");

    my $pack_msg = GitP2P::Proto::Daemon::build_data(
        "recv_pack", \$pack_data);
    sleep $cfg->{debug_sleep} if exists $cfg->{debug_sleep};
    $sender->write($pack_msg . "\n");
    $sender->write("end\n");
}

# Answers to a heartbeat
func on_hugz(Object $sender, GitP2P::Proto::Daemon $msg) {
    my $hugz_back = GitP2P::Proto::Daemon::build_comm("hugz-back", [""]);
    # sleep $cfg->{debug_sleep} if exists $cfg->{debug_sleep};
    $sender->write($hugz_back . "\n"); # I don't know who's gonna hug the pieces that die
}


my $loop = IO::Async::Loop->new;

$loop->listen(
    service => $cfg->{port},
    socktype => 'stream',

    on_stream => sub {
        my ($stream) = @_;
        $log->info("HAS STREAM $stream");

        $stream->configure(
            on_read => sub {
                my ($sender, $buffref, $eof) = @_;
                return 0 if $eof;

                my $msg = GitP2P::Proto::Daemon->new;
                $msg->parse(\$$buffref);

                if (not exists $operations{$msg->op_name}) {
                    my $cmd = $msg->op_name;
                    $log->info("Invalid command: " . $msg->op_name . "\n");
                    $sender->write("NACK: Invalid command - '$cmd'\n");
                } else {
                    $log->info("Exec command: " . $msg->op_name . "\n");
                    $operations{$msg->op_name}->($sender, $msg);
                }

                $$buffref = "";

                return 0;
            }
        );

        $loop->add($stream);
    },

    on_resolve_error => sub { $log->info("Cannot resolve - $_[0]\n"); },
    on_listen_error => sub { $log->info("Cannot listen\n"); },
);

$log->info("Starting loop");
$loop->run;
