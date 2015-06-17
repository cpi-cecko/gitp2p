package GitP2P::Core::Finder;

use v5.20;

use Moose;
use Method::Signatures;
use Path::Tiny;
use IO::Socket::INET;


func get_relay(Str $config_file_name is ro) {
    my @config = path($config_file_name)->lines;
    my ($relay_list) = grep { /relays=/ } @config;
    my @relays = split /,/, (split /=/, $relay_list)[1];

    return $relays[0];
}

func establish_connection(Str $address, Str $cfg) {
    my $local_port = 47778;
    if ($cfg ne "" && path($cfg)->exists) {
        $local_port = int ((path($cfg)->lines({chomp=>1}))[0]);
    } 
    elsif ($cfg ne "") {
        $local_port = int $cfg;
    }
    warn "Addr: $address; local_port: $local_port\n";
    my $s = IO::Socket::INET->new(PeerAddr => $address,
                                  LocalPort => $local_port,
                                  ReuseAddr => SO_REUSEADDR,
                                  ReusePort => SO_REUSEPORT,
                                  Proto => 'tcp');
    # Reminder: Handling failures should be easier than rocket-science
    return ($s or handle_failure($!));
}

sub handle_failure($) {
    my $err = shift;
    # return 0
    #     if $err =~ /Connection refused/;

    # TODO: Fix error handling
    warn "Cannot create socket: $!";
    return 0;
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
