#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;

use GitP2P::Proto::Relay;


plan tests => 18;


# Building messages
my $msg = GitP2P::Proto::Relay::build("list", ["peer1", "peer2"]);
ok ($msg eq "0.1.0 list peer1:peer2",
    'Simple message');

my $msg_no_data = GitP2P::Proto::Relay::build("no-data", []);
ok ($msg_no_data eq "0.1.0 no-data ",
    'Message without data');

my $msg_no_op_name = eval { GitP2P::Proto::Relay::build("", ["sad"]); };
ok (defined $@ && $@ =~ /op_name is empty/,
    'Message without op_name');

my $msg_invalid_op_name = eval { GitP2P::Proto::Relay::build("op123", ["123"]); };
ok (defined $@ && $@ =~ /op_name has invalid characters/,
    'Message with op_name containing invalid characters');

# Parsing messages
my $msg_parse = GitP2P::Proto::Relay->new;

$msg_parse->parse("0.1.0 hello johny:brent:matilda");
ok ($msg_parse->version eq "0.1.0",
    'Simple message valid version');
ok ($msg_parse->op_name eq "hello",
    'Simple message valid op_name');
ok ($msg_parse->op_data eq "johny:brent:matilda",
    'Simple message valid op_data');

$msg_parse->parse("0.1.0 list");
ok ($msg_parse->version eq "0.1.0",
    'No-data message valid version');
ok ($msg_parse->op_name eq "list",
    'No-data message valid op_name');
ok ($msg_parse->op_data eq "",
    'No-data message valid empty op_data');

$msg_parse->parse("0.1.0 simple ");
ok ($msg_parse->version eq "0.1.0",
    'No-data2 message valid version');
ok ($msg_parse->op_name eq "simple",
    'No-data2 message valid op_name');
ok ($msg_parse->op_data eq "",
    'No-data2 message valid op_data');

eval { $msg_parse->parse("0.1.0 simple-: 123:456"); };
ok (defined $@ && $@ =~ /op_name has invalid characters/,
    'Parsing message with op_name containing invalid characters');

eval { $msg_parse->parse("0.1.0 list_me!"); };
ok (defined $@ && $@ =~ /op_name has invalid characters/,
    'Parsing message with no data and op_name containing invalid characters');

eval { $msg_parse->parse("0.1.0 hell000 "); };
ok (defined $@ && $@ =~ /op_name has invalid characters/,
    'Parsing message with no data and op_name containing invalid characters 2');

eval { $msg_parse->parse("0.1.0 "); };
ok (defined $@ && $@ =~ /op_name is empty/,
    'Parsing message without op_name');

eval { $msg_parse->parse("0.1.033"); };
ok (defined $@ && $@ =~ /Incompatible version/,
    'Parsing message with incompatible version');
