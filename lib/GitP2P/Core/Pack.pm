#!/usr/bin/perl

#
# TODO: 
#   1. unpack/pack by bytes

package Pack;
use v5.020;
use Moose;
use Method::Signatures;
use Path::Tiny;


has 'id' => (is => 'bare', isa => 'Str');
has 'repo' => (is => 'bare', isa => 'Str');
has 'data' => (is => 'bare', isa => 'Str');


method chunk_repo(Str \$repo_dir is ro) {
    my $path = path("$repo_dir/.git/objects/pack");

    my %packs_files = (
            grep { qr/.*?.idx/ } $path->children,
            grep { qr/.*?.pack/ } $path->children
        );

    say join "\n",
        %packs_files;
}

# method pack_repo(Str \$repo_data is ro) {
#     return ("") if length $repo_data == 0;
# 
#     my @split;
#     my $beg = 0;
#     my $inc = 10;
# 
#     while ($beg < length $repo_data) {
#         push @split, substr $repo_data, $beg, $inc;
#         $beg += $inc;
#     }
# 
#     return @split;
# }
# 
# method unpack_repo(ArrayRef[Str] $packs_data is ro) {
#     my @packs = @$packs_data;
#     my $repo_data;
# 
#     for (@packs) {
#         $repo_data .= $_;
#     }
# 
#     return $repo_data;
# }
# 
# method export_repo(Str \$repo_dir is ro) {
#     opendir(my $dh, $repo_dir) or 
#         die "Can't opendir $repo_dir: $!";
# 
#     while (readdir $dh) {
#         if -d $_;
#         say "$repo_dir/$_";
#     }
# 
#     closedir($dh);
# }
# 
# method import_repo(Str \$repo_dest_dir is ro) {
# }


no Moose;

1;
