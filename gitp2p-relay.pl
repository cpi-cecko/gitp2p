#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use FindBin;
use lib "$FindBin::Bin/lib";

use Path::Tiny;
use Method::Signatures;
use IO::Async::Stream;
use IO::Async::Loop;
use IO::Select;
use JSON::XS;

use GitP2P::Proto::Relay;
use GitP2P::Proto::Daemon;
use GitP2P::Core::Finder;


my %operations = ( "get-peers" => \&on_get_peers
                 , "add-peer"  => \&on_add_peer
                 );

die "Usage: ./gitp2p-relay <cfg_path>"
    if scalar @ARGV == 0;
my $cfg_file = $ARGV[0];
my $cfg = JSON::XS->new->ascii->decode(path($cfg_file)->slurp);


func on_add_peer(Object $sender, Str $op_data) {
    if ($op_data =~ /^(.*:.*)/) {
        my $addr = $sender->read_handle->peerhost;
        my $port = $sender->read_handle->peerport;
        my $peer_entry = $1 . ' ^ ' . $addr . ':' . $port . "\n";
        print "[INFO] Received entry: $peer_entry";

        my $peers = path("peers");
        if ($peers->exists && grep { /\Q$peer_entry\E/ } $peers->lines) {
            $sender->write("NACK: already added\n");
        } else {
            $sender->write("ACK!\n");
            $peers->append(($peer_entry));
        }
    }
}

func on_get_peers(Object $sender, Str $op_data) {
    if ($op_data =~ /^(.*):(.*)$/) {
        my ($repo_name, $owner_id) = ($1, $2);
        print "[INFO] Searching repo: $repo_name from $owner_id\n";

        my $peers = path("peers");
        if ($peers->exists) {
            my @peers_addr;
            for ($peers->lines) {
                if ($_ =~ /\Q$repo_name\E:\Q$owner_id\E(?::[^\s]+)? \^ (.*)\n$/) {
                    push @peers_addr, $1;
                }
            }

            @peers_addr = get_hugged_peers(\@peers_addr);
            scalar @peers_addr == 0
                and print "[INFO] No peers for repo\n"
                    and $sender->write("NACK: no peers for repo\n") 
                        and return;

            print "[INFO] Sending " . (join ',', @peers_addr) . "\n";
            $sender->write((join ',', @peers_addr) . "\n");
        } else {
            print "[INFO] No peers\n";
            $sender->write("NACK: no peers file found\n");
        }
    }
}

func get_hugged_peers(ArrayRef[Str] $peer_addresses) {
    my $pSelect = IO::Select->new;
    for (@$peer_addresses) {
        my $pS = GitP2P::Core::Finder::establish_connection($_, \$cfg->{port_hugz}, 0);
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
                    print "[INFO] Invalid command: " . $msg->op_name . "\n";
                    $sender->write("NACK: Invalid command - '$cmd'\n");
                } else {
                    print "[INFO] Exec command: " . $msg->op_name . "\n";
                    $operations{$msg->op_name}->($sender, $msg->op_data);
                } 

                $$buffref = "";

                return 0;
            }
        );

        $loop->add($stream);
    },

    # TODO: Use a logger
    on_resolve_error => sub { print STDERR "Cannot resolve - $_[0]\n"; },
    on_listen_error => sub { print STDERR "Cannot listen\n"; },
);


$loop->run;
