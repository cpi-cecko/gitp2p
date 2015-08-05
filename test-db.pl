#!/usr/bin/env perl

use strict;
use warnings;
use v5.020;


use FindBin;
use lib "$FindBin::Bin/lib";
use DBIx::NoSQL;
use Data::Dumper;


sub show_peers($) {
    my $store = shift;
    my $repo = $store->get('Repo' => 'clone-simple');
    my @peers = @{$repo->{peers}};
    for my $peer (@peers) {
        say $peer->{addr} . ':' . $peer->{port};
    }
}

my $store = DBIx::NoSQL->connect('store.sqlite');
$store->set('Repo', 'clone-simple', {
        repo => 'clone-simple'
      , peers => [
              {
                  name => 'cpi-cecko',
                  addr => '127.0.0.1',
                  port => 42001,
                  refs => ['refs/heads/master?470f', 
                           'refs/heads/test?137b',
                           'refs/tags/v1.0?7887']
              },
              {
                  name => 'cpi-cecko',
                  addr => '127.0.0.1',
                  port => 42002,
                  refs => ['refs/heads/master?470f']
              },
              {
                  name => 'pesho',
                  addr => '127.0.0.1',
                  port => 42003,
                  refs => ['refs/heads/test?137b', 
                           'refs/heads/tags/v1.0?7887']
              }
          ]
    });

say "Initial store";
show_peers $store;

my $repo = $store->get('Repo' => 'clone-simple');
push @{$repo->{peers}}, {
    name => 'ilarion',
    addr => '127.0.0.1',
    port => '4444',
    refs => []
};

say "After pushing to array ref";
show_peers $store;

$store->set('Repo' => 'clone-simple', $repo);

say "After setting";
show_peers $store;
