#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use Getopt::Long;
use Pod::Usage;
use Method::Signatures;
use Path::Tiny;
use IO::Socket::INET;


my $man = 0;
my $help = 0;

GetOptions('help|?' => \$help, 
           man      => \$man,
           'init=s' => \&repo_init,
           upload   => \&repo_upload,
           push     => \&repo_push_to_swarm,
           fetch    => \&repo_fetch_from_swarm,
           list     => \&repo_list,
       ) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;


func repo_init(Object $opt_name is ro, Str $repo_dir is ro) {
    # TODO: Check if there's a valid repo at $repo_dir
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

    system("git", "config", "--bool", "core.bare", "true");
    system("rm", "-rf", $bare_repo_path)
        if $? == -1;
}

# Fetches the list of available relays and uploads sends its address
# there.
func repo_upload(Object $opt_name is ro, Str $dummy is ro) {
    my @config = path("./gitp2p-config")->lines;
    my ($relay_list) = grep { /relays=/ } @config;
    my ($port_list) = grep { /ports=/ } @config;
    my @relays = split /,/, (split /=/, $relay_list)[1];
    my @ports = split /,/, (split /=/, $port_list)[1];

    my $repo_name = path(path("./")->absolute)->basename;
    my $user_id = `git config --get user.email`;
    chomp $user_id;


    # TODO: Combine relays with ports!
    my $s = IO::Socket::INET->new(PeerAddr => $relays[0],
                                  PeerPort => $ports[0],
                                  LocalPort => 47778,
                                  ReuseAddr => SO_REUSEADDR,
                                  ReusePort => SO_REUSEPORT,
                                  Proto => 'tcp')
                              or die "Cannot create connection to relay";

    my $packet = $repo_name . ":" . $user_id;
    say "[INFO] Packet $packet";
    $s->send($packet);

    my $resp = <$s>;

    say "[INFO] Response: $resp";
    close $s;
}


__END__

=head1 NAME

gitp2p - A peer-to-peer git hosting service.

=head1 SYNOPSIS

gitp2p [--help, --man, --init [repo-dir], --upload, --push, --fetch]

 Options:
   -help        brief help message
   -man         full documentation

   -init        init a bare git repo from the repo at [repo-dir]
   -upload      upload an initted bare repo to the p2p swarm
   -push        push changes to the swarm
   -fetch       fetch changes from the swarm
   -list        lists available gitp2p repos

=head1 OPTIONS

=over 8

=item B<-help>

Prints a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

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

=item B<-list>

Lists available gitp2p repositories.

=back

=head1 DESCRIPTION

B<gitp2p> is designed to provide peer-to-peer git hosting capabilities.
This way, the open-source community could establish free and stable 
repositories for sharing and working on great projects.

=cut
