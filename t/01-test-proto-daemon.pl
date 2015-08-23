#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;

use GitP2P::Proto::Daemon;
use GitP2P::Proto::Packet;


plan tests => 30;


# Building data messages
my $data_no_op_empty = eval { GitP2P::Proto::Daemon::build_data("", \""); };
ok (defined $@ && $@ =~ /Data message without op_name/,
    "Empty data no op");

my $data_empty = GitP2P::Proto::Daemon::build_data("opp", \"");
ok ($data_empty eq "0.1.0 dopp ",
    "Empty data message");

my $data_short = GitP2P::Proto::Daemon::build_data("hugz", \"you");
ok ($data_short eq "0.1.0 dhugz eW91",
    "Short data message");

my $packet = GitP2P::Proto::Packet->new;
$packet->write("want 6f06a47f3751e61a1ce99c89a9d3854c8d723e32");
$packet->write("want ece9869b327e24683452bbd13a95e72237f5e8dd");
$packet->write("have ece9869b327e24683452bbd13a95e72237f5e8dd");
my $data_long = GitP2P::Proto::Daemon::build_data("fetch", \$packet->to_send);
ok ($data_long eq "0.1.0 dfetch d2FudCA2ZjA2YTQ3ZjM3NTFlNjFhMWNlOTljODlhOWQzODU0YzhkNzIzZTMyCndhbnQgZWNlOTg2OWIzMjdlMjQ2ODM0NTJiYmQxM2E5NWU3MjIzN2Y1ZThkZApoYXZlIGVjZTk4NjliMzI3ZTI0NjgzNDUyYmJkMTNhOTVlNzIyMzdmNWU4ZGQK",
    "Long data message");

# Building comm messages
my $comm_no_op_empty = eval { GitP2P::Proto::Daemon::build_comm("", [""]); };
ok (defined $@ && $@ =~ /Comm message without op_name/,
    "Empty comm no op");

my $comm_empty = GitP2P::Proto::Daemon::build_comm("opp", [""]);
ok ($comm_empty eq "0.1.0 copp ",
    "Empty comm message");

my $comm_short = GitP2P::Proto::Daemon::build_comm("add-peer", ["saddly"]);
ok ($comm_short eq "0.1.0 cadd-peer saddly",
    "Short comm message");

my $comm_long = GitP2P::Proto::Daemon::build_comm("exch",
    ["saddly","viability123","passage,,,keykeykey"]);
ok ($comm_long eq "0.1.0 cexch saddly:viability123:passage,,,keykeykey",
    "Long comm message");

# General parse
my $msg_parse = GitP2P::Proto::Daemon->new;
eval { $msg_parse->parse(\"0.1.0 sad"); };
ok (defined $@ && $@ =~ /No op_name in message/,
    "Parse message without type");
$@ = undef;

eval { $msg_parse->parse(\"dsass"); };
ok (defined $@ && $@ =~ /No version/,
    "Parse message no version");
$@ = undef;

eval { $msg_parse->parse(\"0.2.0 dsad "); };
ok (defined $@ && $@ =~ /Incompatible version/,
    "Parse message bad version");
$@ = undef;

eval { $msg_parse->parse(\"010 dsad "); };
ok (defined $@ && $@ =~ /No version/,
    "Parse data bad version 2");
$@ = undef;

# Parsing data messages
my $data_parse = GitP2P::Proto::Daemon->new;
eval { $data_parse->parse(\"0.1.0 d "); };
ok (defined $@ && $@ =~ /No op_name in message/,
    "Parse data no op and no data");
$@ = undef;

eval { $data_parse->parse(\"0.1.0 d sad"); };
ok (defined $@ && $@ =~ /No op_name in message/,
    "Parse data no op, but has data");
$@ = undef;

eval { $data_parse->parse(\"0.1.0 d"); };
ok (defined $@ && $@ =~ /No op_name in message/,
    "Parse data no op, no space");
$@ = undef;

$data_parse->parse(\"0.1.0 dfetch d2FudCA2ZjA2YTQ3ZjM3NTFlNjFhMWNlOTljODlhOWQzODU0YzhkNzIzZTMyCndhbnQgZWNlOTg2OWIzMjdlMjQ2ODM0NTJiYmQxM2E5NWU3MjIzN2Y1ZThkZApoYXZlIGVjZTk4NjliMzI3ZTI0NjgzNDUyYmJkMTNhOTVlNzIyMzdmNWU4ZGQK");
ok ($data_parse->op_name eq "fetch",
    "Parsing long data; checking op_name");
ok ($data_parse->op_data eq "want 6f06a47f3751e61a1ce99c89a9d3854c8d723e32\nwant ece9869b327e24683452bbd13a95e72237f5e8dd\nhave ece9869b327e24683452bbd13a95e72237f5e8dd\n",
    "Parsing long data; checking op_data");
ok ($data_parse->version eq "0.1.0",
    "Parsing long data; checking version");

$data_parse->parse(\"0.1.0 dhugz eW91");
ok ($data_parse->op_name eq "hugz",
    "Parsing short data; checking op_name");
ok ($data_parse->op_data eq "you",
    "Parsing short data; checking op_data");
ok ($data_parse->version eq "0.1.0",
    "Parsing short data; checking version");

# Parsing comm messages
my $comm_parse = GitP2P::Proto::Daemon->new;
eval { $comm_parse->parse(\"0.1.0 c "); };
ok (defined $@ && $@ =~ /No op_name in message/,
    "Parse comm no op and no data");
$@ = undef;

eval { $comm_parse->parse(\"0.1.0 c sad"); };
ok (defined $@ && $@ =~ /No op_name in message/,
    "Parse comm no op, but has data");
$@ = undef;

eval { $data_parse->parse(\"0.1.0 c"); };
ok (defined $@ && $@ =~ /No op_name in message/,
    "Parse comm no op, no space");
$@ = undef;

$comm_parse->parse(\"0.1.0 clist hello");
ok ($comm_parse->op_name eq "list",
    "Parse short comm; checking op_name");
ok ($comm_parse->op_data eq "hello",
    "Parse short comm; checking op_data");
ok ($comm_parse->version eq "0.1.0",
    "Parse short comm; checking version");

$comm_parse->parse(\"0.1.0 cadd clone-simple:cpi-cecko\@gmail.com:6f06a47f3751e61a1ce99c89a9d3854c8d723e32");
ok ($comm_parse->op_name eq "add",
    "Parse long comm; checking op_name");
ok ($comm_parse->op_data eq "clone-simple:cpi-cecko\@gmail.com:6f06a47f3751e61a1ce99c89a9d3854c8d723e32",
    "Parse long comm; checking op_data");
ok ($comm_parse->version eq "0.1.0",
    "Parse long comm; checking version");
