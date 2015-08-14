#!/usr/bin/env perl

use strict;
use warnings;
use 5.020;

use FindBin;
use lib "$FindBin::Bin/lib";


use List::MoreUtils qw/firstidx/;

use GitP2P::Core::Common;


my @shas = 
  (
     "d6179dd6e7b82037a31213352050947d9871fdfa", # 0
     "85ed55580080997d9b7472c469aef032205beb4f", # 5
     "ee1cd66210c2ef37128c2e0d18e7aebdbdb315b4", # 4
     "97dc78d7effd48a9d6d79a5106b77139cedbb443", # 1
     "6764fde8d790da01201d03b9e49f19b510b3b1b6", # 3
     "4ca0d03ac84a150ea8512409e6617a39e066c197", # 2
  );

my @rev_list = split /\n/, qx(git rev-list HEAD);
@rev_list = ($rev_list[0]);

my $latest_ref = GitP2P::Core::Common::most_recent(
                    sub { 
                        my $elem = shift;
                        print "Elem: $elem\n";
                        firstidx { print "Rev: $_\n"; $_ eq $elem; } reverse @rev_list;
                    }, \@shas);

print $latest_ref . "\n";
