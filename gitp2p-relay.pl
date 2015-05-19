#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

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

                while ($$buffref =~ s/^(.*?:.*?)//) {
                    print "Received a line $1\n";
                    $self->write("ACK!");
                }

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
