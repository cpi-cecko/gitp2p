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
use List::Util qw/reduce/;

use GitP2P::Proto::Daemon;

use App::Daemon qw/daemonize/;
daemonize();

my %operations = ( "obj_count" => \&on_obj_count,
                 , "give" => \&on_give,
                 );

my %cfg = ( repos => {
                  "gitp2p" => "/mnt/files/PROJECTS/gitp2p/"
                , "01-repo-one-file-master" => "/mnt/files/PROJECTS/gitp2p/t/testRepos/01-repo-one-file-master/01-repo-one-file-master/"
            }
            , "port" => "47001"
          );

# The daemon maintains a file with refs to each repo by name
func on_obj_count(Object $sender, Str $repo_name) {
    my $repo = path($cfg{repos}->{$repo_name} . ".git/objects/");
    say "[INFO] repo " . $repo->realpath;

    $repo->child("pack")->exists
        and $repo->child("pack")->children
            and unpack_packs($repo->child("pack"), $repo);

    say "[INFO] repo " . $repo->realpath;
    my @obj_dirs = $repo->children(qr/^\d\d/);
    my $obj_count = reduce { $a + scalar $b->children } 0, @obj_dirs;

    say "[INFO] object count: $obj_count";

    $sender->write("$obj_count\n");
}

func unpack_packs(Object $pack_dir, Object $repo_dir) {
    my $temp_dir = path((path($repo_dir->absolute . "/../../temp")->mkpath)[0]);
    say "[INFO] Temp dir " . $temp_dir;
    $pack_dir->move($temp_dir);
    my $pack = ($temp_dir->children(qr/^pack-.*\.pack$/))[0];
    say "[INFO] pack " . $pack->realpath;

    # TODO: escape $pack
    system ("git unpack-objects <" . $pack->realpath) == -1
        and die $?;

    $temp_dir->remove;
}

func on_give(Object $sender, Str $op_data) {
    my ($repo_name, $count, $offset) = split /:/, $op_data;

    my $repo = path($cfg{repos}->{$repo_name} . ".git/objects/");
    say "[INFO] repo " . $repo->realpath;

    $repo->child("pack")->exists
        and $repo->child("pack")->children
            and unpack_packs($repo->child("pack"), $repo);

    my @obj_dirs = $repo->children(qr/^\d\d/);
    my @objects = map { 
                     my $dir = $_;
                     map { 
                         $dir->absolute . "/" . $_->basename
                     } $dir->children
                  } @obj_dirs;

    ($offset > $#objects or $offset+$count-1 > $#objects or
     $offset < 0 or $count < 0)
        and die ("Invalid slice " . $offset . ":" . ($offset+$count-1));

    @objects = @objects[$offset ... $offset+$count-1];
    say "[INFO] objects " . join "\n", @objects;

    my $user_id = `git config --local --get user.email`;

    for my $obj (@objects) {
        my @obj_path = split /\//, $obj;
        my ($dir_hash, $file_hash) = @obj_path[-2, -1];
        print "$dir_hash:$file_hash\n";
        my $msg = GitP2P::Proto::Daemon::build_data("recv", 
            {'user_id' => $user_id,
             'type' => 'objects',
             'hash' => "$dir_hash$file_hash",
             'cnts' => path($obj)->slurp_raw
            });
        print "$msg\n";
        $sender->write($msg . "\n")
    }
    $sender->write("end\n");
}


my $loop = IO::Async::Loop->new;

$loop->listen(
    service => $cfg{port},
    socktype => 'stream',

    on_stream => sub {
        my ($stream) = @_;

        $stream->configure(
            on_read => sub {
                my ($sender, $buffref, $eof) = @_;
                return 0 if $eof;

                my $msg = GitP2P::Proto::Daemon->new;
                $msg->parse($$buffref);

                if (not exists $operations{$msg->op_name}) {
                    my $cmd = $msg->op_name;
                    print "[INFO] Invalid command: " . $msg->op_name . "\n";
                    $sender->wrte("NACK: Invalid command - '$cmd'\n");
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

    on_resolve_error => sub { print STDERR "Cannot resolve - $_[0]\n"; },
    on_listen_error => sub { print STDERR "Cannot listen\n"; },
);


$loop->run;


=begin comment

# Peer-to-peer prototype
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

=end comment
=cut
