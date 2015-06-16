package GitP2P::Core::Common;

use strict;
use warnings;
use v5.020;


use Path::Tiny;
use Method::Signatures;
use File::Copy;
use File::Temp qw/tempfile/;
use File::pushd; # I love dirs ^_^
use IPC::Open2;


func list_objects(Str $git_dir) {
    my $abs_path = path($git_dir)->absolute . "/";

    my $dir = pushd $abs_path;
    my @objects = qx(git rev-list --objects --all);

    map { $_ =~ s/^([a-f0-9]{40}).*$/$1/ } @objects;

    return @objects;
}

func create_pack_from_list(ArrayRef[Str] $objects, Str $git_dir) {
    my ($tfh, $tname) = tempfile;
    print $tfh join "", @$objects;

    my $abs_path = path($git_dir)->absolute . "/";
    my $dir = pushd $abs_path; 
    my $packed = qx(git pack-objects --stdout <$tname);

    return $packed;
}

func unpack_packs(Object $pack_dir, Object $repo_obj_dir) {
    # `git unpack-objects` doesn't care about bare repositories
    # Or does it?
    # my $repo_root = $repo_obj_dir->parent;
    # my $name = $repo_root->basename;
    # print "Repo name: $name\n";
    # if ($name =~ qr/^.+\.git$/) {
    #     print "Moving '" . $repo_root->absolute . "' to '" . 
    #             $repo_root->parent->absolute . "/.git'\n";
    #     move($repo_root->absolute, $repo_root->parent->absolute . "/.git");
    #     $repo_root = path($repo_root->parent->absolute . "/.git");
    #     $repo_obj_dir = $repo_root->child("objects");
    #     $pack_dir = $repo_obj_dir->child("pack");
    # }

    my $temp_dir = path((path($repo_obj_dir->absolute . "/../../temp")->mkpath)[0]);
    $pack_dir->move($temp_dir);
    my $pack = ($temp_dir->children(qr/^pack-.*\.pack$/))[0];
    say "[INFO] pack " . $pack->realpath;


    # Ensure that we're in the git repo. Otherwise unpack-objects may mess up
    # things for us.
    system ("pushd " . $repo_obj_dir->absolute . "../../");
    system ("git unpack-objects <" . $pack->realpath) == -1
        and die $?;
    system ("popd");

    # if ($name =~ qr/^.+\.git$/) {
    #     print "Moving '" . $repo_root->parent->absolute . "' to '" . 
    #             $repo_root->absolute . "/.git'\n";
    #     move($repo_root->parent->absolute . "/.git", $repo_root->absolute);
    # }

    #$temp_dir->remove_tree;
}


1;
