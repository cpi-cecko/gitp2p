#
# The packet protocol just represents a format for sending git objects ids 
# through the net. It's a sub-protocol in the sense that it gets embeded in
# a data-daemon protocol.
# Currently, it doesn't need any versioning because we just parse the contents
# as they are.
#
# pkt_line format ABNF
# ====================
#
# message = repo NL id NL *wants *haves
#
# repo = "repo" SP user_id SP repo_name
# id = "id" SP 1*DIGIT SP 1*DIGIT
# wants = "want" SP obj-id NL
# haves = "have" SP obj-id NL
#
# user_id = *ALNUM
# repo_name = *ALNUM
#
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
