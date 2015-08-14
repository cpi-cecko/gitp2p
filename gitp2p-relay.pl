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
use IO::Select;
use JSON::XS;
use Log::Log4perl;
use DBIx::NoSQL;

use GitP2P::Proto::Relay;
use GitP2P::Proto::Daemon;
use GitP2P::Proto::Packet;
use GitP2P::Core::Finder;


Log::Log4perl::init_and_watch("$FindBin::Bin/gitp2p-log.conf", 'HUP');
my $log = Log::Log4perl->get_logger("gitp2p.relay");
$log->info("Relay RUNNING");

my %operations = ( "get-peers" => \&on_get_peers
                 , "add-peer"  => \&on_add_peer
                 , "list-refs" => \&on_list_refs
                 );

$log->logdie("Usage: ./gitp2p-relay <cfg_path>")
    if scalar @ARGV == 0;
my $cfg_file = $ARGV[0];

$log->logdie("Config doesn't exist") unless path($cfg_file)->exists;

my $cfg = JSON::XS->new->ascii->decode(path($cfg_file)->slurp);
# 
# NoSQL DB layout
# {
#   Repo: [
#       <repo_name>: {
#           repo: <repo_name>,
#           peers: [
#              { name: <peer_name>
#              , addr: <peer_addr>
#              , port: <peer_port>
#              , refs: [<peer_ref>]
#              }
#           ]
#       }
#   ]
# }
#
my $peer_store = DBIx::NoSQL->connect('peers.sqlite');


func on_add_peer(Object $sender, Str $op_data) {
    # repo:user_id:refs
    $log->info("Add peer data: $op_data");
    if ($op_data =~ /^(?<repo>.*?):(?<user>.*?):(?<refs>.*)/) {
        my $addr = $sender->read_handle->peerhost;
        my $port = $sender->read_handle->peerport;

        my $peer_entry = {
            name => $+{user}
          , addr => $addr
          , port => $port
          , refs => [split /:/, $+{refs}]
        };

        if ($peer_store->exists('Repo' => $+{repo})) {
            my $repo = $peer_store->get('Repo' => $+{repo});
            push @{$repo->{peers}}, $peer_entry;
        } else {
            $peer_store->set('Repo', $+{repo}, {
                    repo => $+{repo}
                  , peers => [$peer_entry]
                });
        }
        use Data::Dumper;
        $log->info("Received entry:\n" . Dumper($peer_entry));
        $sender->write("ACK!\n");
    }
}

func on_get_peers(Object $sender, Str $op_data) {
    if ($op_data !~ /^(.*):(.*)$/) {
        $sender->write("NACK: Invalid data format [$op_data]");
        return;
    }

    my ($repo_name, $owner_id) = ($1, $2);
    $log->info("Searching repo: $repo_name from $owner_id\n");

    !path('peers.sqlite')->exists && !$peer_store->exists('Repo' => $repo_name)
        and $log->info("No peers\n")
            and $sender->write("NACK: no peers file found\n")
                and return;

    my $repo = $peer_store->get('Repo' => $repo_name);
    my @peers_addr;
    for my $peer (@{$repo->{peers}}) {
        push @peers_addr, $peer->{addr} . ':' . $peer->{port};
    }

    @peers_addr = get_hugged_peers(\@peers_addr);
    scalar @peers_addr == 0
        and $log->info("No peers for repo\n")
            and $sender->write("NACK: no peers for repo\n") 
                and return;

    $log->info("Sending " . (join ',', @peers_addr) . "\n");
    $sender->write((join ',', @peers_addr) . "\n");
}

func get_hugged_peers(ArrayRef[Str] $peer_addresses) {
    my $pSelect = IO::Select->new;
    for (@$peer_addresses) {
        my $pS = GitP2P::Core::Finder::establish_connection($_, $cfg->{port_hugz});
        next if $pS == 0;
        my $hugz = GitP2P::Proto::Daemon::build_comm("hugz", [""]); 
        $pS->send($hugz . "\n");
        $pSelect->add($pS);
    }

    return () unless $pSelect->count;

    my @hugged_handles;
    my $TIMEOUT_SECS = 3;
    while (my @ready = $pSelect->can_read($TIMEOUT_SECS)) {
        @hugged_handles = (@hugged_handles, @ready);
        map { $pSelect->remove($_) } @ready;
    }
    my @hugged = map { $_->peerhost . ":" . $_->peerport } @hugged_handles;
    return @hugged;
}

func on_list_refs(Object $sender, Str $op_data) {
    my ($repo_name, @sender_refs) = split /:/, $op_data;

    # Read all refs from DB
    !$peer_store->exists('Repo' => $repo_name)
        and $log->info("No peers for repo")
            and $sender->write("NACK: No peers for repo")
                and return;

    my $repo = $peer_store->get('Repo' => $repo_name);
    my $refs = {};
    for my $peer (@{$repo->{peers}}) {
        for my $peer_refs (@{$peer->{refs}}) {
            my ($refname, $refsha) = split /\?/, $peer_refs;
            push @{$refs->{$refname}}, $refsha;
        }
    }

    my $refs_packet = GitP2P::Proto::Packet->new;
    $refs_packet->write("repo $repo_name");
    while (my ($ref_name, $ref_sha) = (each %{$refs})) {
        $refs_packet->write("$ref_name " . join ",", @{$ref_sha});
    }

    # Send the list to all peers except the sender
    my @peer_addresses;
    my $sender_addr = 
        $sender->read_handle->peerhost . ':' . $sender->read_handle->peerport;
    my $pSelect = IO::Select->new;
    for my $peer (@{$repo->{peers}}) {
        my $addr = $peer->{addr} . ':' . $peer->{port}; 

        next 
            if $addr eq $sender_addr;

        push @peer_addresses, $addr;
        my $pS = GitP2P::Core::Finder::establish_connection($addr);
        $pSelect->add($pS);
        my $ref_list_msg = GitP2P::Proto::Daemon::build_data(
            "list", \$refs_packet->to_send);
        $log->info("Sending ref packet: $ref_list_msg");
        $pS->send($ref_list_msg);
    }

    # Reap the latest refs list
    $log->info("Reaping latest refs list");
    my $TIMEOUT_SECS = 3;
    my $unique_refs = {};
    while (my @ready = $pSelect->can_read($TIMEOUT_SECS)) {
        for my $peer (@ready) {
            my $ref = <$peer>;
            chomp $ref;
            $log->info("Reaped_out ref: [$ref]");
            while ($ref !~ /^end$/) {
                my $parsed_ref = GitP2P::Proto::Daemon->new;
                $parsed_ref->parse(\$ref);
                my ($ref_name, $ref_sha) = split /:/, $parsed_ref->op_data;

                ${$unique_refs->{$ref_name}} = $ref_sha;

                $ref = <$peer>;
                chomp $ref;
                $log->info("Reaped_in ref: [$ref]");
            }
            $log->info("Processing ready peers");
        }
        $log->info("Waiting peers");
    }

    # Send a list of unique latest refs to sender
    $log->info("Sending unique latest refs to sender");
    my $unique_refs_msg = 
        join ':',
            map { $_ = 
                    ${$unique_refs->{$_}} . "?" . $_
                        if defined ${$unique_refs->{$_}}
                } %{$unique_refs};

    # TODO: Check if each received ref is in the DB. Also check whether there's
    # only one ref for each branch.

    # TODO: Use protocol to send data back to client
    $log->info("Refs msg: [$unique_refs_msg]");
    $sender->write($unique_refs_msg . "\n");
    # $sender->write("end\n");
}


my $loop = IO::Async::Loop->new;

# TODO: Query other relays if no info here
$loop->listen(
    service => $cfg->{port_relay},
    socktype => 'stream',

    on_stream => sub {
        my ($stream) = @_;
        
        $stream->configure(
            on_read => sub {
                my ($sender, $buffref, $eof) = @_;
                return 0 if $eof;

                my $msg = GitP2P::Proto::Relay->new;
                $msg->parse($$buffref);

                if (not exists $operations{$msg->op_name}) {
                    my $cmd = $msg->op_name;
                    $log->info("Invalid command: " . $msg->op_name . "\n");
                    $sender->write("NACK: Invalid command - '$cmd'\n");
                } else {
                    $log->info("Exec command: " . $msg->op_name . "\n");
                    $operations{$msg->op_name}->($sender, $msg->op_data);
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


$loop->run;
