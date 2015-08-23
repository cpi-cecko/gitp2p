#
# The Daemon protocol is used for communication between peers. Currently, it 
# has two parts - command and data.
#
# Daemon protocol format ABNF
# ===========================
#
# message   = header SP type op_name SP data
#
# header    = version
# type      = d / c
# op_name   = Str
# data      = (1*(ops ":")) ; type == c
#           / cnts          ; type == d
#
# version = major "." minor "." patch
# cnts      = *base64-Chr
#
# major = *DIGIT
# minor = *DIGIT
# patch = *DIGIT
#
package GitP2P::Proto::Daemon;

use v5.020;

use Moose;
use Method::Signatures;
use MIME::Base64 qw/encode_base64 decode_base64/;


has 'version' => ('is' => 'rw', 'isa' => 'Str');
has 'op_name' => ('is' => 'rw', 'isa' => 'Str');
has 'op_data' => ('is' => 'rw', 'isa' => 'Str');

my $VERSION = '0.1.0';


# TODO: Parse the version better
method parse(Str \$data) {
    my ($version, $msg) = $data =~ /^(\d+\.\d+\.\d+)\s(.*)$/;
    die "No version"
        if not defined $version;

    die "Incompatible version $version" 
        if $version ne $VERSION;

    die "No op_name in message"
        if $msg !~ /^[d|c](\w+)\s/;

    my ($type, $rest) = (substr($msg, 0, 1), substr($msg, 1));

    $self->version($version);
    if ($type eq "d") {
        my ($op_name, $cnts) = split / /, $rest;
        $self->op_name($op_name);
        $self->op_data(decode_base64 $cnts);

        return;
    } elsif ($type eq "c") {
        my ($op_name, $op_data) = split / /, $rest;
        $self->op_name($op_name);
        $self->op_data($op_data);

        return;
    } 

    die ("Invalid pack format");
}

func build_data(Str $op_name, Str \$data is ro) {
    die ("Data message without op_name is invalid!")
        if $op_name eq "";

    my $cnts = encode_base64 $data, "";
    chomp $cnts;

    $VERSION . " " . "d" . join " ", ($op_name, $cnts);
}

func build_comm(Str $op_name, ArrayRef[Str] $query is ro) {
    die ("Comm message without op_name is invalid!")
        if $op_name eq "";

    $VERSION . " " . "c" . $op_name . " " . join ":", @$query;
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
