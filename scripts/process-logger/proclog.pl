#!/usr/bin/perl -w
#
# This is a simple PERL program for opening a UDP ocket & listening for
# UDP logging datagrams.
#
# Each log message is in ASCII and is formatted as:
#
# <file>:<log test>
#
# A hash table (hashing filenames into file handles) is maintained to keep 
# track of open files to which data is logged.  
#
# Usage: basename -s Socket number -d logdir -m Multiple source (1/0)
#
use Socket;
use POSIX;

# Demonize / Angelize
chdir '/';
umask 022;
defined (my $pid = fork) or die "Can't fork: $!";
exit if $pid;
setsid or die "Can't start a new session: $!";

# Save the child pid to a file in /var/run/proclog.pid 
$pid_file = "/var/run/proclog.pid";
open (PIDFH, ">$pid_file") || die ("Failed to open file $pid_file!!\n"); 
print PIDFH "$$\n";
close(PIDFH);

# parse command line options
use Getopt::Std;
our($opt_s, $opt_d, $opt_m);

$socknum = 1025;
$logdir = "/var/log";
$multi=1;   
getopt('sdm');

if ($opt_s) {
    $socknum = $opt_s;
}

if ($opt_d) {
    $logdir = $opt_d;
    printf("logdir=%s\n", $logdir);
}

if ($opt_m) {
    $multi = $opt_m;
}

if (length($logdir) > 1 || $logdir[0] != '.') {
    printf("HEREIAM\n");
    if (! -d $logdir) {
	printf("Invalid target directory specified\n");
	exit;
    }
}

printf("proclog.pl: Listening on socket %d; Logging to '%s' multi=%s\n", 
       $socknum, $logdir, ($multi==1) ? "Y" : "N");

$proto = getprotobyname('udp');
if (socket(LISTEN, PF_INET, SOCK_DGRAM, $proto)) {
    setsockopt(LISTEN, SOL_SOCKET, SO_REUSEADDR, pack("l", 1));
    bind(LISTEN, sockaddr_in($socknum, INADDR_ANY));
    listen(LISTEN, SOMAXCONN);
}
else { 
    print STDERR "Failed to open listening socket : $!\n";
} 
 
 
#
# need to keep a dynamically instantiated table of logfile names to
# file descriptors.
#
while (1) {
    $from = recv(LISTEN, $rcvbuf, 1024, 0); 
    $fromip = inet_ntoa((unpack_sockaddr_in($from))[1]);
    $toip = inet_ntoa((unpack_sockaddr_in(getsockname(LISTEN)))[1]);
    # get the target file
    @fields=split(/:/, $rcvbuf);
    $leaffile=$fields[0];
    
    # handle multiple ip-based subdirectories per SD...
    if ($multi != 0) {
        $dir="$logdir/$fromip";
        if (! -d $dir) {
	    mkdir $dir,0777;
	}
	$file="$dir/$leaffile";
    }
    else {
	$file="$logdir/$leaffile";
    }

    # remove the file prefix from the buffer...
    $outbuf=substr($rcvbuf, length($leaffile)+1);
    #
    # Check to see if the extracted filename already exists in our
    # table of open file decriptors.
    #
    if (! $handles{$file} ) {
	if (open($handles{$file}, ">> $file")) {
	    print "opened $file\n";
	}
	else {
	    print "Failed to open $file !!!\n";
	}
    }

    # write to the file
    syswrite($handles{$file}, "$outbuf\n");
    
    # listen for more messages...
    listen(LISTEN, SOMAXCONN);
}
