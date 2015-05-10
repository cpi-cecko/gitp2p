#!/usr/bin/perl

use Core::Pack;
use Test::More tests => 4;


my $packer = Pack->new;
my @spl = $packer->pack_repo(\"logic beneath the sun");
my @exp = ("logic bene", "ath the su", "n");
is_deeply (\@spl,
           \@exp,
           "pack_repo with a string");
@spl = $packer->pack_repo(\"");
@exp = ("");
is_deeply (\@spl,
           \@exp,
           "pack_repo with empty string");
is ($packer->unpack_repo(["hackuna", " matata"]),
    "hackuna matata",
    "unpack_repo with string");
is ($packer->unpack_repo([""]),
    "",
    "unpack_repo with empty string");
