#!/usr/bin/perl -w
##################################################################################
#
# Author:	Andrew Ludwar - DC Core Services [andrew.ludwar@shaw.ca]
# Date:		March 25th, 2011
# Description:	This script is intended to automate making DNS entries in the IDC
#		lab environment.  This script assumes a novice user, prompts for
#		the appropriate input, and handles updating the zone files.
#
#		Users are restricted to a range of IPs they're allowed to manage.
#		These restrictions are defined in the /etc/named.ips and 
#		/etc/named.users files.  A user is bound to a particular group,
#		and that group is only allowed to allocate certain IPs.
#		DC-Core Services will maintain these files and IP restrictions.
#
#		Groups that are authorized to allocate IPs in the IDC lab will be
#		responsible for maintaining their assigned IP space.  This includes
#		any DNS cleanup.
#
#  Please report any bugs to Andrew Ludwar [andrew.ludwar@shaw.ca]
#
##################################################################################
# User		# Comment					# Date
#=================================================================================
# aludwar	- Script creation				March 25th, 2011
#
##################################################################################

my $input="n";
my $flag="0";
my $address="1";
my $rev_in;
my $rev_ptr;
my $fwd_in;
my $fwd_a;
my @fwd_ips;
my @fwd_header;
my @zonefile;
my $named="/etc/named.conf";
my $named_users="/etc/named.users";
my $named_ips="/etc/named.ips";
my $named_log="/etc/named.log";
chomp($today = qx/\/bin\/date +%h-%d,%Y:%H:%M/);
chomp($user=`logname`);

# Prompt user to use sudo if script not run as root
if($< != 0) {
  print "\nYou must run this script using sudo.\n\n";
  exit 1;
}

# Prompt for user intentions.  Add or delete DNS entries today?
print "\nDo you want to add or delete an entry? (a/d)";
chomp($addordel=<STDIN>);
if($addordel =~ m/^[a]{1}/) {

#############################################################################
# BEGIN reading /etc/named.conf to populate the fwdzones and revzones arrays.
# Had to do some string manipulation to display the zones in a friendlier way
# to the user.  
#############################################################################

open FILE, "$named" or die "Open $named failed! $!\n";
foreach $line (<FILE>) {
  if ($line =~ m/^[\s]+zone/) { push(@zonefile,$line); }
}
close FILE;

$i=0;
foreach $line (@zonefile) {
  $j = index($zonefile[$i],'"',);
  $k = rindex($zonefile[$i],'"',);
  $l = $k - $j;
  $zone = substr($zonefile[$i],$j+1,$l-1);
  @gzone = grep /$zone/, @zones;
  $gcount = @gzone;
  if ($gcount == 0) {
    push(@zones,$zone);
  }
  $i++;
}

@fwdzones = grep /^[a-z]/, @zones;
@revzones_tmp = grep /^[1-9]/, @zones;

$i = 0;
foreach $line (@revzones_tmp) {
  $k = rindex($revzones_tmp[$i],'.',);
  $zone = substr($revzones_tmp[$i],0,$k);
  $revzones_tmp[$i] = $zone;
  $k = rindex($revzones_tmp[$i],'.',);
  $zone = substr($revzones_tmp[$i],0,$k);
  $revzones_tmp[$i] = $zone;
  $j = index($revzones_tmp[$i],'.',);
  $k = rindex($revzones_tmp[$i],'.',);
  $oc3 = substr($revzones_tmp[$i],0,$j);
  $oc1 = substr($revzones_tmp[$i],$k+1,,);
  $l = $k - $j;
  $oc2 = substr($revzones_tmp[$i],$j+1,$l-1);
  $zone = "$oc1.$oc2.$oc3.arpa";
  push(@revzones,$zone); 
  $i++;
}
###########################################################################
# END reading in /etc/named.conf to populate fwdzones and revzones arrays.
###########################################################################

###########################################################################
# BEGIN prompting the user to select available zone files for editing.
###########################################################################

while ($input ne "y") {
  print "\nPlease select the domain for your host:\n";
  for ($x=0; $x<=$#fwdzones; $x++) { $y=$x+1; print $y,". ","$fwdzones[$x]\n"; }
  print "\nYour selection: ";
  chomp($a=<STDIN>);
  if ($a == "0" || $a > $y) { print "\nInvalid selection.  Try again.\n"; redo; }
  if ($a > 0 && $a <= $y) { $domain = $fwdzones[$a-1]; }

  ipstart:
  print "\nPlease select the IP subnet for your host:\n";
  for ($x=0; $x<=$#revzones; $x++) { $y=$x+1; print $y,". ","$revzones[$x]\n"; }
  print "\nYour selection: ";
  chomp($b=<STDIN>);
  if ($b == "0" || $b > $y) { print "\nInvalid selection.  Try again.\n"; goto ipstart; }
  if ($b > 0 && $b <= $y) { $ip = $revzones[$b-1]; }

  print "\nYou have selected $domain and $ip for your host.\n";
  print "Is this correct? (y/n)";
  chomp($input=<STDIN>);
}

###########################################################################
# END prompting the user to select available zone files for editing.
###########################################################################

###########################################################################
# BEGIN checking what user is running the script. Validate what group
# the user is assigned to, and what IP blocks they have access to
###########################################################################

open FILE, "$named_users" or die "Open $named_users failed! $!\n";
@groupfile = <FILE>;
close FILE;

@group = grep /$user/, @groupfile;
$count = @group;
$group = $group[0];
if ($count == 0) { print "\nSorry, user $user is not authorized to run this tool.\n\n"; }

@group = split /:/, $group, 0;

open FILE, "$named_ips" or die "Open $named_ips failed! $!\n";
@ipsfile = <FILE>;
close FILE;

@ips_tmp = grep /$ip/, @ipsfile;
@ips_tmp2 = grep /$group[0]/, @ips_tmp;
$ips = $ips_tmp2[0];

@subnet = split /:/, $ips, 0;
$ips=$subnet[1];
@ips = eval $ips;

#print "User $user is a member of $group[0] and has access to IPs @ips in subnet $subnet[0]\n";

#############################################################################
# END of user, group, & IP validation
#############################################################################

###########################################################################
# BEGIN read in the forward and reverse zone files, seperate out the header
# information from the hostnames or the IPs.
###########################################################################

open REVFILE, "$ip" or die "Open $ip failed! $!\n";
foreach $line (<REVFILE>) {
  if ($line !~ m/^[1-9]|^;[0-9]/) { push(@rev_header,$line); }
  elsif ($line =~ m/^[1-9]/) {
    ($rev_ip,$rev_in,$rev_ptr,$rev_hostname) = split(' ',$line); 
    push(@rev_ips,$rev_ip);
    push(@rev_hostname,$rev_hostname);
  }
}
close REVFILE;

# Read in FWD zone file, seperate out hostname, IP, and header info
open FWDFILE, "$domain" or die "Open $domain failed! $!\n";
foreach $line (<FWDFILE>) {
  if ($line !~ m/^[a-z]{2,3}[0-9]{1,3}/) { push(@fwd_header,$line); }
  elsif ($line =~ m/^[a-z]/) {
    ($fwd_hostname,$fwd_in,$fwd_a,$fwd_ip) = split(' ',$line); 
    push(@fwd_ips,$fwd_ip);
    push(@fwd_hostname,$fwd_hostname);
  }
}
close FWDFILE;

#############################################################################
# END of parsing the fwd and reverse zone files. 
#############################################################################

#############################################################################
# BEGIN prompting the user to select an IP and hostname and validate their
# entries.
#############################################################################

# Sort the reverse IPs numerically, then compare the allocated & authorized IPs
# and store the differences.  This will leave us with an array we can display
# to the user that will contain the AVAILABLE IPs that they are AUTHORIZED to
# allocate.
@sorted = sort {$a <=> $b} @rev_ips;
%sorted = map {$_, 1} @sorted;
@difference = grep {!$sorted {$_}} @ips;

$input="n";

while ($input ne "y") {
  # Display the available IPs to the user
  $x=1;
  print "\nAvailable IPs in $ip for $user: \n";
  foreach $ip (@difference) { 
    printf "%3s %1s", $ip, ":";
    if ($x =~ m/[0]$/) { print "\n"; }
    $x++;
  }
  
  $flag=0;
  # Select an available IP that's within 1-254 range that you're authorized to allocate.
  while ($flag == "0") {
    print "\nPlease select an IP for your host:\n";
    print "Example:  55 : ";
    chomp($address=<STDIN>);
    if ($address =~ m/\b([1-9][0-9]?|1[0-9]{2}|2[0-4][0-9]|25[0-4])\b/) {
      $authorized = grep /^$address(?![0-9])/ , @ips;
      if ($authorized == 1) { 
        $result = grep /^$address(?![0-9])/ , @rev_ips;
        if ($result == 0) { $flag = "1"; }
        else { print "\nAddress is already taken.  Try again.\n"; }
      }
      else { print "\nYou aren't allowed to allocate this IP.  Try again.\n"; }
    }
    else { print "\nYou have entered an invalid address.  Try again.\n"; }
  }
  
  # Select a hostname, and validate it against current DNS standards and existing hosts
  $flag = "0";
  while ($flag == "0") {
    print "\nPlease select a hostname for your host:\n";
    print "Example:  app2 : ";
    chomp($host=<STDIN>);
    if ($host =~ m/^^[a-z]{2,3}[0-9]{1,3}(sc|no|so)?(-nfs|-bck|-cons|-rep|-ob)?$|^pd1[a-z]{2,3}[0-9]{1,3}(sc|no|so){1}(-nfs|-bck|-cons|-rep|-ob)?$/) {
      $result = grep /^$host/ , @fwd_hostname;
      if ($result == "0") { $flag = "1"; }
      else { print "\nHostname is already taken.  Try again.\n"; }
    }
    else { print "\nYou have entered an invalid hostname.  Try again.\n"; }
  }
  
  $formal_ip = substr($ip,0,-4);
  print "\nYou have selected $formal_ip","$address and $host",".","$domain for your entry.\n";
  print "Is this correct? (y/n)";
  chomp($input=<STDIN>);
}
#############################################################################
# END of user input section for IP and hostname
#############################################################################

#############################################################################
# BEGIN processing the zone files for updating. Also make a log entry of the
# IP allocation, and save a backup copy of the zone files in /var/tmp
#############################################################################

##** Serial number processing not needed in IDC lab.  Makefile handles the 
##** co and ci of files, editing S/N's and reloading DNS.  Just run sudo make
##** S/N code kept here in case that changes 

# Find the serial numbers, then extract them 
#$rev_serial = $rev_header[2];
#$fwd_serial = $fwd_header[2];
#$rev_index = index($rev_serial,"2");
#$fwd_index = index($fwd_serial,"2");
#$rev_date = substr($rev_serial,$rev_index,8);
#$fwd_date = substr($fwd_serial,$fwd_index,8);
#$rev_counter = substr($rev_serial,$rev_index + 8,2);
#$fwd_counter = substr($fwd_serial,$fwd_index + 8,2);

# Update the serial number to today's date
#$today = qx/\/bin\/date +%Y%m%d/;
#chomp($today);
#if ($today > $rev_date) { $rev_date = $today; $rev_counter = "00"; }
#else { $rev_counter++; }
#$new_rev_serial = "                                $rev_date$rev_counter   ;   Serial\n";
#if ($today > $fwd_date) { $fwd_date = $today; $fwd_counter = "00"; }
#else { $fwd_counter++; }
#$new_fwd_serial = "                                $fwd_date$fwd_counter   ;   Serial\n";

# Open the FWD and REV files, and slurp into array
open REVFILE, "$ip" or die "Open $ip failed! $!\n";
foreach $line (<REVFILE>) {
  if ($line =~ m/^[1-9]/) {
    push(@rev_file,$line);
  }
}
close REVFILE;
open FWDFILE, "$domain" or die "Open $domain failed! $!\n";
@fwd_file = <FWDFILE>;
close FWDFILE;

# Replace original serial number with the new one
#splice(@rev_header,2,1,$new_rev_serial);
#splice(@fwd_file,2,1,$new_fwd_serial);

# Put new REV entry into new array,  and sort numerically by IP
$rev_entry = "$address	IN	PTR	$host.$domain.\n";
push(@rev_file,$rev_entry);
@rev_out = sort { (split '\t', $a, 2)[0] <=> (split '\t', $b, 2)[0] } @rev_file;

# Append FWD entry at end of array
$fwd_entry = "$host		IN	A	$formal_ip$address\n";
push(@fwd_file,$fwd_entry);

# Take a backup copy and then write data to files
if(!-d "/var/tmp") {
  system("mkdir -p /var/tmp");
  if($? == -1) { print "Cannot mkdir /var/tmp!: $!\n"; }
}
system("cp $ip /var/tmp/$ip");
open TMPOUT, ">$ip" or die "Open $ip failed! $!\n";
print TMPOUT @rev_header;
print TMPOUT @rev_out;
close TMPOUT;

system("cp $domain /var/tmp/$domain");
open TMPOUT, ">$domain" or die "Open $domain failed! $!\n";
print TMPOUT @fwd_file;
close TMPOUT;

open LOGFILE, ">>$named_log" or die "Open $named_log failed! $!\n";
print LOGFILE "$today : $user has assigned $formal_ip$address to $host.$domain\n";
close LOGFILE;

print "Running sudo make...\n";
system("make");

print "\nSuccess.  You have assigned $formal_ip$address to $host.$domain\n\n";
print "Please test resolution of your new entry:\n";
print "\n	dig -x $formal_ip$address\n";
print " 	dig $host.$domain\n";

##############################################################################
# END processing zone files for updates, and logging
##############################################################################
}
if($addordel =~ m/^[d]{1}/) {

  # Prompt user for an IP address to delete
  $flag="0";
  $flag2="0";
  while($flag == "0") {
    print "\nWhat IP would you like to delete?:";
    chomp($input=<STDIN>);
    if($input =~ m/^([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])$/) { 

    #############################################################################
    # BEGIN reading /etc/named.conf to populate the fwdzones and revzones arrays.
    # Had to do some string manipulation to display the zones in a friendlier way
    # to the user.
    #############################################################################
   
    open FILE, "$named" or die "Open $named failed! $!\n";
    foreach $line (<FILE>) {
      if ($line =~ m/^[\s]+zone/) { push(@zonefile,$line); }
    }
    close FILE;
   
    $i=0;
    foreach $line (@zonefile) {
      $j = index($zonefile[$i],'"',);
      $k = rindex($zonefile[$i],'"',);
      $l = $k - $j;
      $zone = substr($zonefile[$i],$j+1,$l-1);
      @gzone = grep /$zone/, @zones;
      $gcount = @gzone;
      if ($gcount == 0) {
        push(@zones,$zone);
      }
      $i++;
    }

    @fwdzones = grep /^[a-z]/, @zones;
    @revzones_tmp = grep /^[1-9]/, @zones;
   
    $i = 0;
    foreach $line (@revzones_tmp) {
      $k = rindex($revzones_tmp[$i],'.',);
      $zone = substr($revzones_tmp[$i],0,$k);
      $revzones_tmp[$i] = $zone;
      $k = rindex($revzones_tmp[$i],'.',);
      $zone = substr($revzones_tmp[$i],0,$k);
      $revzones_tmp[$i] = $zone;
      $j = index($revzones_tmp[$i],'.',);
      $k = rindex($revzones_tmp[$i],'.',);
      $oc3 = substr($revzones_tmp[$i],0,$j);
      $oc1 = substr($revzones_tmp[$i],$k+1,,);
      $l = $k - $j;
      $oc2 = substr($revzones_tmp[$i],$j+1,$l-1);
      $zone = "$oc1.$oc2.$oc3.arpa";
      push(@revzones,$zone);
      $i++;
    }
    ###########################################################################
    # END reading in /etc/named.conf to populate fwdzones and revzones arrays.
    ###########################################################################

    #print "This is the zone file we want to edit: ",@count,"\n";

    $j = rindex($input,".",);
    $ip = substr($input,0,$j);

    @count = grep /$ip/, @revzones;
    $count = @count;
    if($count == 0) {
      print "\nThere is no matching zone file for the IP you entered.\n";
    }
    else {
 
    ###########################################################################
    # BEGIN checking what user is running the script. Validate what group
    # the user is assigned to, and what IP blocks they have access to
    ###########################################################################

    open FILE, "$named_users" or die "Open $named_users failed! $!\n";
    @groupfile = <FILE>;
    close FILE;

    @group = grep /$user/, @groupfile;
    $ucount = @group;
    $group = $group[0];
    #if ($ucount == 0) { print "\nSorry, user $user is not authorized to run this tool.\n\n"; }

    @group = split /:/, $group, 0;

    open FILE, "$named_ips" or die "Open $named_ips failed! $!\n";
    @ipsfile = <FILE>;
    close FILE;

    @ips_tmp = grep /$ip/, @ipsfile;
    @ips_tmp2 = grep /$group[0]/, @ips_tmp;
    $ips = $ips_tmp2[0];

    @subnet = split /:/, $ips, 0;
    $ips=$subnet[1];
    @ips = eval $ips;

    #print "User $user is a member of $group[0] and has access to IPs @ips in subnet $subnet[0]\n";

    #############################################################################
    # END of user, group, & IP validation
    #############################################################################
    
    while($flag2 == 0) {
      open REVFILE, "$count[0]" or die "Open $count[0] failed! $!\n";
        foreach $line (<REVFILE>) {
          if ($line !~ m/^[1-9]|^;[0-9]/) { push(@rev_header,$line); }
          elsif ($line =~ m/^[1-9]/) {
            push(@rev_file,$line);
            push(@rev_ips,$rev_ip);
            push(@rev_hostname,$rev_hostname);
          }
         }
      close REVFILE;
      $flag2=1;
    }
    if ($ucount == 0) { print "\nSorry, user $user is not authorized to run this tool.\n\n"; }

    $ip = substr($input,$j+1,,);
    @auth_ips = grep /$ip/, @ips;
    $count=0;
    $count=@auth_ips;
    if($count == 0) { print "\nYou don't have access to $ip in $count[0]\n"; }
    else {
	$hostname = `/usr/sbin/dig +short -x $input 2>&1`;
	if($hostname eq "") {
	  print "\nThe IP $input is not assigned in DNS.  Please try again.\n";
	  redo;
	}
	@auth_ip = ();
	@auth_ip = grep /$hostname/, @rev_file;
	print @auth_ip;
    	print "\nIs this the entry you want to delete? (y/n)";
	chomp($c=<STDIN>); 
	if($c eq "n") { redo; }
	elsif($c eq "y") {
	  $j = index($hostname,'.',);
	  $k = rindex($hostname,'.',);
	  chomp($domain = substr($hostname,$j+1,));
	  chop($domain);
	  $ip = $count[0];
	  
	  @rev_file = ();
	  open REVFILE, "$ip" or die "Open $ip failed! $!\n";
	  @rev_file = <REVFILE>;	
	  close REVFILE;

	  @fwd_file = ();
	  open FWDFILE, "$domain" or die "Open $domain failed! $!\n";
	  @fwd_file = <FWDFILE>;
	  close FWDFILE;

	  chomp($hostname);
	  chop($hostname);
	  @rev_file_grepped = grep !/$hostname/, @rev_file;
	  @fwd_file_grepped = grep !/$input/, @fwd_file;

	  # Take a backup copy and then write data to files
	  if(!-d "/var/tmp") {
	    system("mkdir -p /var/tmp");
	    if($? == -1) { print "Cannot mkdir /var/tmp!: $!\n"; }
	  }

	  system("cp $ip /var/tmp/$ip");
	  system("cp $domain /var/tmp/$domain");

	  open TMPOUT, ">$ip" or die "Open $ip failed! $!\n";
	  print TMPOUT @rev_file_grepped;
	  close TMPOUT;

	  open TMPOUT, ">$domain" or die "Open $domain failed! $!\n";
	  print TMPOUT @fwd_file_grepped;
	  close TMPOUT;

	  open LOGFILE, ">>$named_log" or die "Open $named_log failed! $!\n";
	  print LOGFILE "$today : $user has deleted $input ($hostname)\n";
	  close LOGFILE;
	  
	  print "Running sudo make...\n";
	  system("make");
	  
	  print "\nSuccess.  You have deleted $input ($hostname)\n\n";
	  print "Please test to confirm your deletion:\n";
	  print "\n	dig -x $input\n";
	  print "	dig $hostname\n";

	  $flag = 1;

	}
	else { print "\nInvalid entry.  Please enter (y/n)\n"; }
    }
    }
    }
    else {
      print "\nYou have entered and invalid IP address.  Try again\n";
    }
  }
}
elsif($addordel !~ m/^[d]{1}|^[a]{1}/) {
  print "\nInvalid selection.  Use (a or d)\n";
  exit 1;  
}
