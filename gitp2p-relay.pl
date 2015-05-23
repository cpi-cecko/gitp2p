#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use FindBin;
use lib "$FindBin::Bin/lib";

use Path::Tiny;
use Method::Signatures;
use IO::Async::Stream;
use IO::Async::Loop;

use GitP2P::Proto::Relay;


my %operations = ( "upload" => \&on_upload
                 , "push"   => \&on_push
                 , "fetch"  => \&on_fetch
                 , "list"   => \&on_list
                 );


func on_upload(Object $sender, Str $op_data) {
    if ($op_data =~ /^(.*:.*)/) {
        my $addr = $sender->read_handle->peerhost;
        my $port = $sender->read_handle->peerport;
        my $peer_entry = $1 . ' ^ ' . $addr . ':' . $port . "\n";
        print "Received entry: $peer_entry";

        my $peers = path("peers");
        if ($peers->exists && grep { /\Q$peer_entry\E/ } $peers->lines) {
            $sender->write("NACK: already added\n");
        } else {
            $sender->write("ACK!\n");
            $peers->append(($peer_entry));
        }
    }
}

func on_push(Object $sender, Str $op_data) {
    if ($op_data =~ /^(.*):(.*)/) {
        my ($repo_name, $user_id) = ($1, $2);
        print "Searching repo '$repo_name' for '$user_id'\n";

        my $peers = path("peers");
        if ($peers->exists) {
            # TODO: Support IPv6
            my @peers_addr;
            for ($peers->lines) {
                if ($_ =~ /\Q$repo_name\E:(?:[^\s]+) \^ (.*)\n$/) {
                    print "Sending to '$1'\n";
                    push @peers_addr, $1;
                }
            }
            $sender->write((join ',', @peers_addr) . "\n");
        }
        else {
            print "No peers!\n";
            $sender->write("NACK: no peers\n");
        }
    }
}

func on_fetch(Object $sender, Str $op_data) {
    $sender->write("NACK: not implemented\n");
}

func on_list(Object $sender, Str $op_data) {
    my @peers = path("peers")->lines;
    chomp(@peers);
    my $peers_list = join ", ", @peers;
    $sender->write($peers_list . "\n");
}


my $loop = IO::Async::Loop->new;

# TODO: Query other relays if no info here
$loop->listen(
    service => "12345",
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
                    $sender->write("NACK: Invalid command - '$cmd'\n");
                } else {
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
