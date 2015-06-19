#!/usr/bin/env perl

use strict;
use warnings;
use v5.020;


use FindBin;
use lib "$FindBin::Bin/lib";

use JSON::XS;
use Data::Dumper;
use Path::Tiny;

# use GitP2P::Proto::Packet;
use GitP2P::Core::Finder;
# use GitP2P::Proto::Daemon;

# use List::MoreUtils qw/indexes/;
# 
# 
# my @vector = (0,1,2,3,4,5,6,7,8,9,10);
# print "Before: " . join " ", @vector;
# my $step = 1;
# my $beg = 4;
# @vector = @vector[map { $_ += $beg } indexes { $_ % $step == 0 } (0..$#vector)];
# @vector = grep { defined $_ } @vector;
# print "\nFrom $beg step $step: " . join " ", @vector;

# use GitP2P::Core::Common;
# 
# my @objects = GitP2P::Core::Common::list_objects("./");
# print @objects;

# my $packed = GitP2P::Core::Common::create_pack_from_list(\@objects, "./");
# print $packed . "\n";

my $cfg = JSON::XS->new->ascii->decode(path("gitp2p-config")->slurp);
my $s = GitP2P::Core::Finder::connect_to_relay(\$cfg);
print "has socket!" if $s;
