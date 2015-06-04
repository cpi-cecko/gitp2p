package GitP2P::Proto::Packet;

use v5.020;

use Moose;
use Method::Signatures;


has 'contents' => (
    is => 'rw',
    isa => 'Str',
    default => '',
    reader => 'to_send'
);


# Appends new line to $self->contents
method write(Str $line) {
    my $pkt_line = $self->contents . $line . "\n";
    $self->contents($pkt_line);
}

# Appends new Packet to $self->contents
method append(GitP2P::Proto::Packet \$pack) {
    $self->contents($self->contents . $pack->contents);
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
