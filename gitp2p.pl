#!/usr/bin/perl


use strict;
use warnings;
use v5.20;

use FindBin;
use lib "$FindBin::Bin/lib";

use Getopt::Long;
use Pod::Usage;
use Method::Signatures;
use Path::Tiny;
use IO::Socket::INET;

use GitP2P::Proto::Relay;
use GitP2P::Proto::Daemon;
use GitP2P::Core::Finder;


my $man = 0;
my $help = 0;
my $cfg = ""; # Currently, the config only contains the port number

GetOptions('help|?'  => \$help, 
           man       => \$man,
           'cfg=s'   => \$cfg,
           'init=s'  => \&repo_init,
           upload    => \&repo_upload,
           push      => \&repo_push,
           fetch     => \&repo_fetch,
           'clone=s' => \&repo_clone,
           list      => \&repo_list,
       ) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;


# Accepts a repo_dir and user_id
# TODO: Try to deduce repo_dir and user_id if not present
# TODO: The user.email is not a user id!!!
func repo_init(Object $opt_name, Str $init_params) {
    # TODO: Check if there's a valid repo at $repo_dir
    my ($repo_dir, $owner_id) = split /:/, $init_params;
    # TODO: User pod2usage
    die ("gitp2p --init <repo_dir>:<owner_id>")
        if not $owner_id;

    my $working_dir = path($repo_dir)->absolute;
    if (length($working_dir) == 0) {
        $working_dir = Path::Tiny->cwd;
    }

    say "[INFO] Working in $working_dir";

    my $repo_name = path($working_dir)->basename;
    my $bare_repo_path = "$working_dir/../$repo_name.git";
    say "[INFO] Bare repo path $bare_repo_path";
    
    system("cp", "-rf", "$working_dir/.git", $bare_repo_path);
    die ("couldn't copy repo")
        if $? == -1;

    system("git", "config", "--file", "$bare_repo_path/config", "--bool", "core.bare", "true");
    system("rm", "-rf", $bare_repo_path)
        if $? == -1;
    system("git", "config", "--file", "$bare_repo_path/config", "user.email", "$owner_id");
}

# Fetches the list of available relays and uploads sends its address
# there.
func repo_upload(Object $opt_name, Str $dummy) {
    my $repo_name = path(path("./")->absolute)->basename;
    my $user_id = `git config --get user.email`;
    chomp $user_id;

    my $relay = GitP2P::Core::Finder::get_relay("gitp2p-config");
    my $s = GitP2P::Core::Finder::establish_connection($relay, $cfg);

    my $msg = GitP2P::Proto::Relay::build("upload", [$repo_name, $user_id]);

    say "[INFO] Message '$msg'";
    $s->send($msg);

    my $resp = <$s>;
    chomp $resp;

    say "[INFO] Response: $resp";
    close $s;
}

# Pushes the repo across the swarm of subscribers
func repo_push(Object $opt_name, Str $dummy) {
    my $relay = GitP2P::Core::Finder::get_relay("gitp2p-config");
    my $s = GitP2P::Core::Finder::establish_connection($relay, $cfg);

    # TODO: Read the local or the global git config?
    my $user_id = `git config --local --get user.email`;
    chomp $user_id;
    my $repo_name = path(path("./")->absolute)->basename;

    my $msg = GitP2P::Proto::Relay::build("push", [$repo_name, $user_id]);

    say "[INFO] Message '$msg'";
    $s->send($msg);

    # expected: comma-sepd ip:port of peers
    my $resp = <$s>;
    chomp $resp;
    if (grep { /NACK:/ } $resp) {
        say "[INFO] No peers";
        return;
    }

    my @peers_addr = split /,/, $resp;

    # system ("git", "gc");
    for my $peer (@peers_addr) {
        # my $pS = GitP2P::Core::Finder::establish_connection($peer, 47778);
        my $packDir = path(".git/objects/pack");
        for my $packFile ($packDir->children) {
            if ($packFile =~ /\.idx$/) {
                my $contents = path($packFile)->slurp_raw;
                my $msg = GitP2P::Proto::Daemon::build("recv",
                    {'user_id' => $user_id, 
                     'type' => "idx",
                     'cnts' => $contents});
                say "Sending index of " . (length $msg) . " bytes to $peer";
                # $pS->send($msg);
            }
            elsif ($packFile =~ /\.pack$/) {
                my $contents = path($packFile)->slurp_raw;
                my $msg = GitP2P::Proto::Daemon::build("recv", 
                    {'user_id' => $user_id, 
                     'type' => "pack",
                     'cnts' => $contents});
                say "Sending pack of " . (length $msg) . " bytes to $peer";
                # $pS->send($msg);
            }
        }
        # close $pS;
    }

    close $s;
}

# Clones a repo by a given name and user id
func repo_clone(Object $opt_name, Str $opt_params) {
    my $relay = GitP2P::Core::Finder::get_relay("gitp2p-config");
    my $s = GitP2P::Core::Finder::establish_connection($relay, $cfg);

    my ($user_id, $repo_name) = split ':', $opt_params;
    my $msg = GitP2P::Proto::Relay::build("clone", [$user_id, $repo_name]);

    say "[INFO] Message '$msg'";
    $s->send($msg);
    
    my $resp = <$s>;
    chomp $resp;

    say "[INFO] Response '$resp'";
    close $s;
}

# Lists available repos
func repo_list(Object $opt_name, Str $dummy) {
    my $relay = GitP2P::Core::Finder::get_relay("gitp2p-config");
    my $s = GitP2P::Core::Finder::establish_connection($relay, $cfg);

    my $msg = GitP2P::Proto::Relay::build("list", [""]);

    say "[INFO] Message '$msg'";
    $s->send($msg);

    my $resp = <$s>;
    chomp $resp;

    say "Available repos: \n  " . join "\n  ", split /, /, $resp;
    close $s;
}


__END__

=head1 NAME

gitp2p - A peer-to-peer git hosting service.

=head1 SYNOPSIS

gitp2p [--help, --man, --cfg config-file, --init [repo-dir], --upload, --push,
        --fetch, --clone user_id:repo_name, --list]

 Options:
   -help        brief help message
   -man         full documentation

   -cfg         specify config file for overriding default options

   -init        init a bare git repo from the repo at [repo-dir]
   -upload      upload an initted bare repo to the p2p swarm
   -push        push changes to the swarm
   -fetch       fetch changes from the swarm
   -clone       clone repo from the swarm
   -list        lists available gitp2p repos

=head1 OPTIONS

=over 8

=item B<-help>

Prints a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=item B<-cfg>

Override defaults from a config file.

=item B<-init>

Init a bare git repository on your machine from the repo at [repo-dir].
If no such directory is specified, gitp2p uses the directory you're currently
in.

=item B<-upload>

Upload the initialized bare repository to the gitp2p swarm. This basically
shares the repository and adds it to the global broadcast board where it
could be pulled and shared by other peers.

=item B<-push>

Pushes your changes to the gitp2p swarm.

=item B<-fetch>

Fetches the latest repo changes from the gitp2p swarm.

=item B<-clone>

Clones a given repo.

=item B<-list>

Lists available gitp2p repositories.

=back

=head1 DESCRIPTION

B<gitp2p> is designed to provide peer-to-peer git hosting capabilities.
This way, the open-source community could establish free and stable 
repositories for sharing and working on great projects.

=cut
