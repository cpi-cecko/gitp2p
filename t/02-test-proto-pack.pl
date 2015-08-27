#!/usr/bin/env perl


use strict;
use warnings;
use v5.020;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;

use GitP2P::Proto::Packet;


plan tests => 3;


my $pack_empty = GitP2P::Proto::Packet->new;
ok ($pack_empty->contents eq "",
    "Empty pack");

my $pack_with_writes = GitP2P::Proto::Packet->new;
$pack_with_writes->write("want your mom");
$pack_with_writes->write("want maikati");
ok ($pack_with_writes->contents eq "want your mom\nwant maikati\n",
    "Pack with writes");

my $pack_with_appends = GitP2P::Proto::Packet->new;
$pack_with_appends->write("hello");
$pack_with_appends->append(\$pack_with_writes);
ok ($pack_with_appends->contents eq "hello\nwant your mom\nwant maikati\n",
    "Pack with appends");
