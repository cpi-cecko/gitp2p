#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use Core::Pack;


my $str = "logic beneath the sun";

my $packer = Pack->new;

my @spl = $packer->pack_repo(\$str);

print 'begin\'';
print for @spl;
print '\'end';
