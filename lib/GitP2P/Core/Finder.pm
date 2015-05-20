package GitP2P::Core::Finder;

use v5.20;

use Moose;
use Method::Signatures;
use Path::Tiny;


func get_relay(Str $config_file_name is ro) {
    my @config = path($config_file_name)->lines;
    my ($relay_list) = grep { /relays=/ } @config;
    my @relays = split /,/, (split /=/, $relay_list)[1];

    return $relays[0];
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
