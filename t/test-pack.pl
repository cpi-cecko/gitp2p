#!/usr/bin/env perl


use strict;
use warnings;
use v5.020;

use FindBin;
use lib "$FindBin::Bin/../lib";

use GitP2P::Proto::Packet;


print "Old pack:\n";
my $pack = GitP2P::Proto::Packet->new;
$pack->write("want your mom");
$pack->write("want maikati");
print $pack->to_send;

print "New pack:\n";
my $new_pack = GitP2P::Proto::Packet->new;
$new_pack->write("hello");
$new_pack->append(\$pack);
print $new_pack->to_send;
