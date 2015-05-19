#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use Socket;


# Receiver
$|++;

my $recv_port = 9000;
my $recv_proto = getprotobyname("udp");

socket(RECV, PF_INET, SOCK_DGRAM, $recv_proto) 
    or die "recv socket: $!";
select((select(RECV), $|=1)[0]);
setsockopt(RECV, SOL_SOCKET, SO_REUSEADDR, 1)
    or die "recv setsockopt: $!";
my $broadcast_addr = sockaddr_in($recv_port, INADDR_ANY);
bind(RECV, $broadcast_addr)
    or die "recv bind: $!";

if (fork() == 0) {
    my $input;
    while (my $addr = recv(RECV, $input, 18, 0)) {
        print "$addr => $input\n";
    }

    exit;
}

# Sender
my $send_proto = getprotobyname("udp");
socket(SEND, PF_INET, SOCK_DGRAM, $send_proto)
    or die "send socket: $!";
select((select(SEND), $|=1)[0]);

my $send_broad_addr = sockaddr_in(9000, INADDR_BROADCAST);
setsockopt(SEND, SOL_SOCKET, SO_BROADCAST, 1);


if (fork() == 0) {
    while (1) {
        send(SEND, "Hello from peer!", 0, $send_broad_addr)
            or die "error at sending: $!";
        sleep(10);
    }
    
    exit;
}


wait();


close RECV;
close SEND;


# use IO::Socket::INET;
# 
# 
# my $port = int(rand(40000)) + 1024;
# 
# my $send_sock = IO::Socket::INET->new(PeerPort  => $port,
#                                       PeerAddr  => inet_itoa(INADDR_BROADCAST),
#                                       Proto     => udp,
#                                       LocalAddr => 'localhost',
#                                       Broadcast => 1)
#                                   or die "Can't bind: $@\n";
# 
# my $recv_sock = IO::Socket::INET->new(PeerPort  => $port,
#                                       PeerAddr  => inet_itoa(INADDR_ANY),
#                                       Proto     => udp,
#                                       LocalAddr => 'localhost')
#                                   or die "Can't listen: $@\n";
# 
# $recv_sock->bind();
# $recv_sock->listen(SOMAXCONN);
# 
# $send_sock->connect();
# 
# while (1) {
#     if (my $line = <$recv_sock>) {
#         print "Received: $line.";
#     }
# 
#     for (my $paddr; $paddr = $send_sock->accept(PEER); close PEER) {
#         print "Hi from $port.$EOL";
#     }
# }
