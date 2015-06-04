package GitP2P::Core::Common;

use strict;
use warnings;
use v5.020;


use Path::Tiny;
use Method::Signatures;
use File::Copy;


func unpack_packs(Object $pack_dir, Object $repo_obj_dir) {
    # `git unpack-objects` doesn't care about bare repositories
    # Or does it?
    my $repo_root = $repo_obj_dir->parent;
    my $name = $repo_root->basename;
    print "Repo name: $name\n";
    if ($name =~ qr/^.*\.git$/) {
        print "Moving '" . $repo_root->absolute . "' to '" . 
                $repo_root->parent->absolute . "/.git'\n";
        move($repo_root->absolute, $repo_root->parent->absolute . "/.git");
        $repo_root = path($repo_root->parent->absolute . "/.git");
        $repo_obj_dir = $repo_root->child("objects");
        $pack_dir = $repo_obj_dir->child("pack");
    }

    my $temp_dir = path((path($repo_obj_dir->absolute . "/../../temp")->mkpath)[0]);
    $pack_dir->move($temp_dir);
    my $pack = ($temp_dir->children(qr/^pack-.*\.pack$/))[0];
    say "[INFO] pack " . $pack->realpath;


    # TODO: escape $pack
    system ("git unpack-objects <" . $pack->realpath) == -1
        and die $?;

    if ($name =~ qr/^.*\.git$/) {
        print "Moving '" . $repo_root->parent->absolute . "' to '" . 
                $repo_root->absolute . "/.git'\n";
        move($repo_root->parent->absolute . "/.git", $repo_root->absolute);
    }

    $temp_dir->remove;
}


1;
