#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use FindBin;
use lib "$FindBin::Bin/lib";

use GitP2P::Proto::Daemon;


my $msg = GitP2P::Proto::Daemon->new;
my $proto = 'cobj_count cpi.cecko@gmail.com:gitp2p';

$msg->parse($proto);

say $msg->op_name;
say $msg->op_data;
