#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;


use FindBin;
use lib "$FindBin::Bin/lib";

use Path::Tiny;
use File::Copy;
use Method::Signatures;
use IO::Async::Stream;
use IO::Async::Loop;
use List::Util qw/reduce/;
use List::MoreUtils qw/indexes/;

use GitP2P::Proto::Daemon;
use GitP2P::Core::Common qw/unpack_packs/;

use App::Daemon qw/daemonize/;
daemonize();

my %operations = ( "list"      => \&on_list,
                 , "fetch"     => \&on_fetch,
                 , "obj_count" => \&on_obj_count,
                 , "give"      => \&on_give,
                 );

# TODO: These absolute paths are not so good for configs
my %cfg = ( repos => {
                  "gitp2p" => "/media/files/PROJECTS/.git"
                , "01-repo-one-file-master" => "/media/files/PROJECTS/gitp2p/t/testRepos/01-repo-one-file-master/.git"
            }
            , "port" => "47001"
          );


# Lists refs for a given repo
func on_list(Object $sender, GitP2P::Proto::Daemon $msg) {
    my $repo_name = $msg->op_data;
    my $repo_refs_path = path($cfg{repos}->{$repo_name} . "/info/refs");
    say "[INFO] Refs at " . $repo_refs_path->realpath;

    my $refs = $repo_refs_path->slurp;

    my $refs_to_send = '';
    # Don't send remote refs
    for my $ref (split /\n/, $refs) {
        $ref !~ /remotes/
            and $refs_to_send .= $ref . "\n";
    }
    say "[INFO] Refs: $refs_to_send";

    # TODO: rework protocol
    my $refs_msg = GitP2P::Proto::Daemon::build_data("recv",
        {'user_id' => 'dummyuid',
         'type'    => 'refs',
         'hash'    => 'dummy',
         'cnts'    => $refs_to_send
        });
    say "[INFO] Refs message: $refs_msg";
    $sender->write($refs_msg . "\n");
}

# Returns wanted object by client
func on_fetch(Object $sender, GitP2P::Proto::Daemon $msg) { 
    # print "[INFO] $msg->op_data";

    my $objects = $msg->op_data;

    # print "[INFO] $objects";
    # my $hexed = join "", map { sprintf "%02x", ord $_ } split //, $objects;
    # print "[INFO] $hexed";
    my ($repo, $id, @rest) = split /\n/, $objects;
    # TODO: Validate repo line
    my (undef, $repo_name, $repo_owner) = split / /, $repo;
    # TODO: Validate id
    my (undef, $beg, $step) = split / /, $id;

    my @wants;
    my @haves;
    for my $pkt_line (@rest) {
        $pkt_line =~ /^(\w+)\s([a-f0-9]{40})\n?$/;
        $1 eq "want"
            and push @wants, $2;
        $1 eq "have"
            and push @haves, $2;
    }

    my $repo_obj = path($cfg{repos}->{$repo_name} . "/objects/");
    say "[INFO] repo " . $repo_obj->realpath;

    $repo_obj->child("pack")->exists
        and $repo_obj->child("pack")->children
            and GitP2P::Core::Common::unpack_packs($repo_obj->child("pack"), $repo_obj);

    my @obj_dirs = $repo_obj->children(qr/^[a-f0-9]{2}/);
    my @objects = map { 
                     my $dir = $_;
                     map { 
                         $dir->absolute . "/" . $_->basename
                     } $dir->children
                  } @obj_dirs;

    # TODO: Use wants and haves properly
    # Get every $step-th object beggining from $beg
    @objects = @objects[map { $_ += $beg } indexes { $_ % $step == 0 } (0..$#objects)];
    @objects = grep { defined $_ } @objects;
    say "[INFO] objects " . join "\n", @objects;

    my $config_file = $cfg{repos}->{$repo_name} . "/config";
    my $user_id = qx(git config --file $config_file --get user.email);
    say "[INFO] config: $config_file";
    say "[INFO] user id: $user_id";

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

# The daemon maintains a file with refs to each repo by name
# func on_obj_count(Object $sender, Str $repo_name) {
#     my $repo_obj = path($cfg{repos}->{$repo_name} . "/objects/");
#     say "[INFO] repo " . $repo_obj->realpath;
# 
#     $repo_obj->child("pack")->exists
#         and $repo_obj->child("pack")->children
#             and unpack_packs($repo_obj->child("pack"), $repo_obj);
# 
#     say "[INFO] repo " . $repo_obj->realpath;
#     my @obj_dirs = $repo_obj->children(qr/^\d\d/);
#     my $obj_count = reduce { $a + scalar $b->children } 0, @obj_dirs;
# 
#     say "[INFO] object count: $obj_count";
# 
#     $sender->write("$obj_count\n");
# }
# 
# func on_give(Object $sender, Str $op_data) {
#     my ($repo_name, $count, $offset) = split /:/, $op_data;
# 
#     my $repo = path($cfg{repos}->{$repo_name} . "/objects/");
#     say "[INFO] repo " . $repo->realpath;
# 
#     $repo->child("pack")->exists
#         and $repo->child("pack")->children
#             and unpack_packs($repo->child("pack"), $repo);
# 
#     my @obj_dirs = $repo->children(qr/^\d\d/);
#     my @objects = map { 
#                      my $dir = $_;
#                      map { 
#                          $dir->absolute . "/" . $_->basename
#                      } $dir->children
#                   } @obj_dirs;
# 
#     ($offset > $#objects or $offset+$count-1 > $#objects or
#      $offset < 0 or $count < 0)
#         and die ("Invalid slice " . $offset . ":" . ($offset+$count-1));
# 
#     @objects = @objects[$offset ... $offset+$count-1];
#     say "[INFO] objects " . join "\n", @objects;
# 
#     my $config_file = $cfg{repos}->{$repo_name} . "/config";
#     my $user_id = system "git config --file " . $config_file . " --get user.email";
# 
#     for my $obj (@objects) {
#         my @obj_path = split /\//, $obj;
#         my ($dir_hash, $file_hash) = @obj_path[-2, -1];
#         print "$dir_hash:$file_hash\n";
#         my $msg = GitP2P::Proto::Daemon::build_data("recv", 
#             {'user_id' => $user_id,
#              'type' => 'objects',
#              'hash' => "$dir_hash$file_hash",
#              'cnts' => path($obj)->slurp_raw
#             });
#         print "$msg\n";
#         $sender->write($msg . "\n")
#     }
#     $sender->write("end\n");
# }


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
                    $operations{$msg->op_name}->($sender, $msg);
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
