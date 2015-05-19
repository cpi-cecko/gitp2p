#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use Path::Tiny;
use Method::Signatures;
use IO::Async::Stream;
use IO::Async::Loop;


my $loop = IO::Async::Loop->new;

$loop->listen(
    service => "12345",
    socktype => 'stream',

    on_stream => sub {
        my ($stream) = @_;
        
        $stream->configure(
            on_read => sub {
                my ($self, $buffref, $eof) = @_;
                return 0 if $eof;

                my ($op_name, $op_data) = split / /, $$buffref;
                print "op: '$op_name', data: '$op_data'\n";

                if ($op_name =~ /upload/) {
                    if ($op_data =~ /^(.*:.*)/) {
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
                elsif ($op_name =~ /push/) {
                }
                elsif ($op_name =~ /fetch/) {
                }
                elsif ($op_name =~ /list/) {
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
