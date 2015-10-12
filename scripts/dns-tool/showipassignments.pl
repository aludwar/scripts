#!/usr/bin/perl -w
##################################################################################
#
# Author:       Andrew Ludwar - DC Core Services [andrew.ludwar@sjrb.ca]
# Date:         March 25th, 2011
# Description:  This script is intended to automate making DNS entries in the IDC
#               lab environment.  This script assumes a novice user, prompts for
#               the appropriate input, and handles updating the zone files.
#
#               Users are restricted to a range of IPs they're allowed to manage.
#               These restrictions are defined in the /etc/named.ips and
#               /etc/named.users files.  A user is bound to a particular group,
#               and that group is only allowed to allocate certain IPs.
#               DC-Core Services will maintain these files and IP restrictions.
#
#               Groups that are authorized to allocate IPs in the IDC lab will be
#               responsible for maintaining their assigned IP space.  This includes
#               any DNS cleanup.
#
#  Please report any issues to DC - Core Services [shawcrtidccore@sjrb.ca]
#  Please report any bugs to Andrew Ludwar [andrew.ludwar@sjrb.ca]
#
##################################################################################
# User          # Comment                                       # Date
#=================================================================================
# aludwar       - Script creation                               March 25th, 2011
#
##################################################################################

my @revzones;
my $named="/etc/named.conf";
my $named_users="/etc/named.users";
my $named_ips="/etc/named.ips";
chomp($user=`logname`);


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
# BEGIN checking what user is running the script. Validate what group
# the user is assigned to, and what IP blocks they have access to
###########################################################################

open FILE, "$named_users" or die "Open $named_users failed! $!\n";
@groupfile = <FILE>;
close FILE;

@group = grep /$user/, @groupfile;
$ucount = @group;
$group = $group[0];
if ($ucount == 0) { print "\nSorry, user $user is not authorized to run this tool.\n\n"; }

@group = split /:/, $group, 0;

open FILE, "$named_ips" or die "Open $named_ips failed! $!\n";
@ipsfile = <FILE>;
close FILE;

@ips_tmp = grep /$group[0]/, @ipsfile;

foreach $line (@ips_tmp) {
  ($subnet,$range,$group) = split(/:/, $line, 3);
  push(@subnet,$subnet);
  push(@range,$range);
}
$subnet = @subnet;

print "User $user is a member of $group[0] and has authority over these IPs:\n";
for($x=0;$x < $subnet; $x++){
  @ips = ();
  @ips = eval $range[$x];
  $j = rindex($subnet[$x],'.',);
  $formalsubnet = substr($subnet[$x],0,$j);

  print "\nIP assignments in $subnet[$x] : \n";

  foreach $line (@ips) {
    $formalip = $formalsubnet . "." . $line;
    $resolve = `/usr/sbin/dig +short -x $formalip 2>&1`;
    chomp($resolve);
    if ($resolve) {
      print "$formalip - $resolve\n";
    } 
    else {
      print "$formalip - AVAILABLE\n";
    }
    
  }
}

#############################################################################
# END of user, group, & IP validation
#############################################################################
