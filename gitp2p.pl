#!/usr/bin/perl

use strict;
use warnings;
use v5.20;

use Getopt::Long;
use Pod::Usage;


my $man = 0;
my $help = 0;

GetOptions('help|?' => \$help, 
           man      => \$man
           # init     => \&repo_init,
           # upload   => \&repo_upload,
           # push     => \&repo_push_to_swarm,
           # fetch    => \&repo_fetch_from_swarm
       ) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;


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

=back

=head1 DESCRIPTION

B<gitp2p> is designed to provide peer-to-peer git hosting capabilities.
This way, the open-source community could establish free and stable 
repositories for sharing and working on great projects.

=cut
