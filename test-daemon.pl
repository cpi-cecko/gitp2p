#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;


use FindBin;
use lib "$FindBin::Bin/lib";

use Path::Tiny;
use Method::Signatures;
use List::Util qw/reduce/;


my %cfg = ( repos => {
                  "gitp2p" => "/mnt/files/PROJECTS/gitp2p/"
                , "01-repo-one-file-master" => "/mnt/files/PROJECTS/gitp2p/t/testRepos/01-repo-one-file-master/01-repo-one-file-master/"
            }
            , "port" => "47001"
          );


# The daemon maintains a file with refs to each repo by name
func on_obj_count(Str $repo_name) {
    my $repo = path($cfg{repos}->{$repo_name} . ".git/objects/");
    say "[INFO] repo " . $repo->realpath;

    $repo->child("pack")->exists
        and $repo->child("pack")->children
            and unpack_packs($repo->child("pack"), $repo);

    say "[INFO] repo " . $repo->realpath;
    my @obj_dirs = $repo->children(qr/^\d\d/);
    my $obj_count = reduce { $a + scalar $b->children } 0, @obj_dirs;

    say "[INFO] object count: $obj_count";
}

func unpack_packs(Object $pack_dir, Object $repo_dir) {
    my $temp_dir = path((path($repo_dir->absolute . "/../../temp")->mkpath)[0]);
    say "[INFO] Temp dir " . $temp_dir;
    $pack_dir->move($temp_dir);
    my $pack = ($temp_dir->children(qr/^pack-.*\.pack$/))[0];
    say "[INFO] pack " . $pack->realpath;

    # TODO: escape $pack
    system ("git unpack-objects <" . $pack->realpath) == -1
        and die $?;

    $temp_dir->remove;
}

func on_give(Str $op_data) {
    my ($repo_name, $count, $offset) = split /:/, $op_data;

    my $repo = path($cfg{repos}->{$repo_name} . ".git/objects/");
    say "[INFO] repo " . $repo->realpath;

    $repo->child("pack")->exists
        and $repo->child("pack")->children
            and unpack_packs($repo->child("pack"), $repo);

    my @obj_dirs = $repo->children(qr/^\d\d/);
    my @objects = map { 
                     my $dir = $_;
                     map { 
                         $dir->absolute . "/" . $_->basename
                     } $dir->children
                  } @obj_dirs;

    ($offset > $#objects or $offset+$count-1 > $#objects or
     $offset < 0 or $count < 0)
        and die ("Invalid slice " . $offset . ":" . ($offset+$count-1));

    say "[INFO] repos: " . join "\n", @objects[$offset .. $offset+$count-1];
}

on_give('01-repo-one-file-master:3:0');
