package GitP2P::Proto::Daemon;

use v5.20;

use Moose;
use Method::Signatures;
use MIME::Base64 qw/encode_base64 decode_base64/;


has 'op_name' => ('is' => 'rw', 'isa' => 'Str');
has 'op_data' => ('is' => 'rw', 'isa' => 'Str');


# message   = type op_name SP data
# type      = d | c
# op_name   = Str
# data      = [ ops : ]               if type == c
#           | user_id SP data_type SP hash SP cnts if type == d
# user_id   = Str
# data_type = Str
# hash      = Str
# cnts      = Str_base64

# TODO: Make the param a ref
# TODO: Split in two, separate protocols
# TODO: Escape special characters like ':'
method parse(Str $data) {
    my ($type, $rest) = (substr($data, 0, 1), substr($data, 1));
    say $rest;
    if ($type eq "d") {
        my ($op_name, $user_id, $data_type, $hash, $cnts) = split / /, $rest;
        $self->op_name($op_name);
        $self->op_data(join ":", ($user_id, $data_type, $hash, decode_base64 $cnts));

        return;
    } elsif ($type eq "c") {
        my ($op_name, $op_data) = split / /, $rest;
        $self->op_name($op_name);
        $self->op_data($op_data);

        return;
    } 

    die ("Invalid pack format");
}

# TODO: Check for members' existence
func build_data(Str $op_name, HashRef[Str] $op_data is ro) {
    my $cnts = encode_base64 ${op_data}->{cnts};
    chomp $cnts;
    my $user_id = ${op_data}->{user_id};
    chomp $user_id;
    my $hash = ${op_data}->{hash};
    chomp $hash;
    my $type = ${op_data}->{type};
    chomp $type;

    "d" . join " ", ($op_name, $user_id, $type, $hash, $cnts);
}

func build_comm(Str $op_name, ArrayRef[Str] $query is ro) {
    "c" . $op_name . " " . join ":", @$query;
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
