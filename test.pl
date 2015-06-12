#!/usr/bin/env perl

use strict;
use warnings;
use v5.020;


use List::MoreUtils qw/indexes/;


my @vector = (0,1,2,3,4,5,6,7,8,9,10);
print "Before: " . join " ", @vector;
my $step = 1;
my $beg = 4;
@vector = @vector[map { $_ += $beg } indexes { $_ % $step == 0 } (0..$#vector)];
@vector = grep { defined $_ } @vector;
print "\nFrom $beg step $step: " . join " ", @vector;
