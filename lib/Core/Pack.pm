#!/usr/bin/perl

package Pack;
use v5.20;
use Moose;
use Method::Signatures;


has 'id' => (is => 'bare', isa => 'Str');
has 'repo' => (is => 'bare', isa => 'Str');
has 'data' => (is => 'bare', isa => 'Str');


method pack_repo(Str \$repo_data is ro) {
    return ("") if length $repo_data == 0;

    my @split;
    my $beg = 0;
    my $inc = 10;

    while ($beg < length $repo_data) {
        push @split, substr $repo_data, $beg, $inc;
        $beg += $inc;
    }

    return @split;
}

method unpack_repo(ArrayRef[Str] $packs_data is ro) {
    my @packs = @$packs_data;
    my $repo_data;

    for (@packs) {
        $repo_data .= $_;
    }

    return $repo_data;
}


no Moose;

1;
