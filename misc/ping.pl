#!/usr/bin/perl -w
#perl script used to read a list of IPs from a file, ping them, and report which IPs are down or unreachable

#declare functions to be used
use Net::Ping;
use Fcntl;

#declare variables, must set source IP address($my_addr is set to local IP) for icmp ping to work
$ipfile="ips.txt";
#$my_addr="10.0.36.53";
$outputfile="downhosts.txt";

#open the input and output files, error if unable to open, delete output file if already exists
open(IPs, $ipfile) || die("Could not open $ipfile!\n");
unlink $outputfile;
sysopen(OUTPUTFILE,'downhosts.txt',O_RDWR|O_EXCL|O_CREAT,0755) || die("Could not open $outputfile!\n");

#start the ping process for each entry in $ipfile
$p = Net::Ping->new("icmp");
#$p->bind($my_addr);
while ($ipaddress = <IPs> ) {
  chomp $ipaddress;
  print "$ipaddress is NOT REACHABLE! \n" unless $p->ping($ipaddress, 2); #display output to shell
  printf OUTPUTFILE "$ipaddress is NOT REACHABLE! \n" unless $p->ping($ipaddress, 2); #throw output to a file
  sleep(1);
}
$p->close();
#end the ping process

#close outstanding files
close(OUTPUTFILE);
close(IPs);
