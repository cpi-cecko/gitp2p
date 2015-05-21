package GitP2P::Proto::Daemon;

use v5.20;

use Moose;
use Method::Signatures;
use MIME::Base64 qw/encode_base64/;


has 'op_name' => ('is' => 'rw', 'isa' => 'Str');
has 'op_data' => ('is' => 'rw', 'isa' => 'Str');


method parse(Str \$data) {
    ...;
}

# TODO: Check for members' existence
func build(Str $op_name, HashRef[Str] $op_data is ro) {
    my $cnts = encode_base64 ${op_data}->{cnts};
    my $user_id = ${op_data}->{user_id};
    my $type = ${op_data}->{type};

    join " ", ($op_name, $user_id, $type, $cnts);
}

1;
