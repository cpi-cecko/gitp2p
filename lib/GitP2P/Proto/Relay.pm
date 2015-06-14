# 
# The Relay protocol is used by the client to communicate with the relays. It
# may become obsolete at the moment when we start using the peer-to-peer 
# network alone for keeping the peer data.
#
# Relay protocol format ABNF
# ==========================
#
# message = header SP op-name SP op-data
#
# header  = version
# op-name = *("_" "a"."z" "A"."Z")
# op-data = *(ALNUM ":")
#
# version = major "." minor "." patch ["." meta]
# major   = *DIGIT
# minor   = *DIGIT
# patch   = *DIGIT
# meta    = *(ALNUM / "-" / ".")
#
package GitP2P::Proto::Relay;

use v5.020;

use Moose;
use Method::Signatures;


my $VERSION = "0.1.0";

has 'op_name' => ('is' => 'rw', 'isa' => 'Str');
has 'op_data' => ('is' => 'rw', 'isa' => 'Str');
has 'version' => ('is' => 'rw', 'isa' => 'Str');


method parse(Str $data) {
    my ($version, $op_name, $op_data) = split / /, $data;

    die "Incompatible version $version"
        if $version ne $VERSION;

    $self->version($version);
    $self->op_name($op_name);
    $self->op_data($op_data);
}

func build(Str $op_name is ro, ArrayRef[Str] $op_data is ro) {
    $VERSION . " " . $op_name . " " . join ":", @$op_data;
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
