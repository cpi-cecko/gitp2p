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

func establish_connection(Str $address, \$config_file is ro, $is_hash = 1) {
    my $local_port = $is_hash ? $config_file->{port_daemon} : $config_file;

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
