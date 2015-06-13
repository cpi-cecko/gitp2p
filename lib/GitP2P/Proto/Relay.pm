package GitP2P::Proto::Relay;

use v5.20;

use Moose;
use Method::Signatures;


has 'op_name' => ('is' => 'rw', 'isa' => 'Str');
has 'op_data' => ('is' => 'rw', 'isa' => 'Str');


# relay protocol format ABNF
#
# message = op-name SP op-data
#
# op-name = *("_" "a"."z" "A"."Z")
# op-data = *(ALNUM ":")

method parse(Str $data) {
    my ($op_name, $op_data) = split / /, $data;
    $self->op_name($op_name);
    $self->op_data($op_data);
}

func build(Str $op_name is ro, ArrayRef[Str] $op_data is ro) {
    $op_name . " " . join ":", @$op_data;
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
