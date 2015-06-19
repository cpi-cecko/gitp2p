package GitP2P::Core::Finder;

use v5.20;

use Moose;
use Method::Signatures;
use Path::Tiny;
use IO::Socket::INET;


# TODO: Don't rely on preferred relay
func get_relay(\$config_file is ro) {
    my $preferred_relay = $config_file->{preferred_relay};
    return $config_file->{relays}->{$preferred_relay};
}

func connect_to_relay(\$config_file is ro) {
    my $relay = get_relay(\$config_file);
    my $s = GitP2P::Core::Finder::establish_connection($relay, \$config_file);
    return $s if $s;

    my @all_relays = values %{$config_file->{relays}};
    @all_relays = grep { $_ ne $relay } @all_relays;
    while (!$s) {
        $relay = shift @all_relays;
        last unless $relay;

        $s = GitP2P::Core::Finder::establish_connection($relay, \$config_file);
    }

    die "Can't connect with any relay"
        if !$s && $#all_relays == -1;

    return $s;
}

func establish_connection(Str $address, \$config_file is ro, $is_hash = 1) {
    my $local_port = $is_hash ? $config_file->{port_daemon} : $config_file;

    warn "Addr: $address; local_port: $local_port\n";
    my $s = IO::Socket::INET->new(PeerAddr => $address,
                                  LocalPort => $local_port,
                                  ReuseAddr => SO_REUSEADDR,
                                  ReusePort => SO_REUSEPORT,
                                  Proto => 'tcp');

    return ($s or handle_failure());
}

sub handle_failure {
    warn "Cannot create socket: $!";
    return 0;
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
