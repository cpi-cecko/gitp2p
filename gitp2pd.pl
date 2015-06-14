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
use JSON::XS;
use Data::Dumper;

use GitP2P::Proto::Daemon;
use GitP2P::Core::Common qw/unpack_packs/;

use App::Daemon qw/daemonize/;
daemonize();

my %operations = ( "list"      => \&on_list,
                 , "fetch"     => \&on_fetch,
                 );

die "Usage: ./gitp2pd <cfg_path>"
    if scalar @ARGV == 0;
my $cfg_file = $ARGV[0];

my $cfg = JSON::XS->new->ascii->decode(path($cfg_file)->slurp);


# Lists refs for a given repo
func on_list(Object $sender, GitP2P::Proto::Daemon $msg) {
    my $repo_name = $msg->op_data;
    my $repo_refs_path = path($cfg->{repos}->{$repo_name} . "/info/refs");
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
    my $objects = $msg->op_data;

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

    my $repo_obj = path($cfg->{repos}->{$repo_name} . "/objects/");
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

    my $config_file = $cfg->{repos}->{$repo_name} . "/config";
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


my $loop = IO::Async::Loop->new;

$loop->listen(
    service => $cfg->{port},
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
