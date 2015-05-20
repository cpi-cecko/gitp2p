package GitP2P::Proto::Relay;

use v5.20;

use Moose;
use Method::Signatures;


has 'op_name' => ('is' => 'rw', 'isa' => 'Str');
has 'op_data' => ('is' => 'rw', 'isa' => 'Str');


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
