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

func connect_to_relay(\$config_file is ro, Maybe[Int] $local_port = undef) {
    my $relay = get_relay(\$config_file);
    my $s = GitP2P::Core::Finder::establish_connection($relay, $local_port);
    return $s if $s;

    my @all_relays = values %{$config_file->{relays}};
    @all_relays = grep { $_ ne $relay } @all_relays;
    while (!$s) {
        $relay = shift @all_relays;
        last unless $relay;

        $s = GitP2P::Core::Finder::establish_connection($relay, $local_port);
    }

    die "Can't connect with any relay"
        if !$s && $#all_relays == -1;

    return $s;
}

func establish_connection(Str $address, Maybe[Int] $local_port = undef) {
    my $warn_str = "Addr: $address; ";
    $warn_str .= "local_port: $local_port" if defined $local_port;
    warn $warn_str;

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
