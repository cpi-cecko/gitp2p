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


my $loop = IO::Async::Loop->new;

# TODO: Query other relays if no info here
$loop->listen(
    service => "12345",
    socktype => 'stream',

    on_stream => sub {
        my ($stream) = @_;
        
        $stream->configure(
            on_read => sub {
                my ($self, $buffref, $eof) = @_;
                return 0 if $eof;

                my $msg = GitP2P::Proto::Relay->new;
                $msg->parse($$buffref);

                if ($msg->op_name =~ /upload/) {
                    if ($msg->op_data =~ /^(.*:.*)/) {
                        my $addr = $self->read_handle->peerhost;
                        my $port = $self->read_handle->peerport;
                        my $peer_entry = $1 . ' ^ ' . $addr . ':' . $port . "\n";
                        print "Received entry: $peer_entry";

                        my $peers = path("peers");
                        if ($peers->exists && grep { /\Q$peer_entry\E/ } $peers->lines) {
                            $self->write("NACK: already added\n");
                        } else {
                            $self->write("ACK!\n");
                            $peers->append(($peer_entry));
                        }
                    }
                } 
                elsif ($msg->op_name =~ /push/) {
                }
                elsif ($msg->op_name =~ /fetch/) {
                }
                elsif ($msg->op_name =~ /list/) {
                    my @peers = path("peers")->lines;
                    chomp(@peers);
                    my $peers_list = join ", ", @peers;
                    $self->write($peers_list . "\n");
                }
                else {
                    # Send NACK!
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
