#!/usr/bin/perl
#
# SCTP Conformance Test Suite Implementation
# (C) Copyright Fujitsu Ltd. 2008, 2009
#
# This file is part of the SCTP Conformance Test Suite implementation.
#
# The SCTP Conformance Test Suite implementation is free software;
# you can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2 as published by
# the Free Software Foundation.
#
# The SCTP Conformance Test Suite implementation is distributed in the
# hope that it will be useful, but WITHOUT ANY WARRANTY; without even
# the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GNU CC; see the file COPYING.  If not, write to
# the Free Software Foundation, 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.
#
# Please send any bug reports or fixes you make to the
# email address(es):
#    networktest sctp <networktest-sctp@lists.sourceforge.net>
#
# Or submit a bug report through the following website:
#    http://networktest.sourceforge.net/
#
# Written or modified by:
#    Hiroaki Kago <linuxsctp-kg@ml.css.fujitsu.com>
#    Wei Yongjun <yjwei@cn.fujitsu.com>
#
# Any bugs reported given to us we will try to fix... any fixes shared will
# be incorporated into the next SCTP release.
#
##############################################################################

use SimpleRemote;

sub configInterfaceTN($$$$;$);
sub configInterfaceNUT($$$$;$);
sub getRemoteMAC($);
sub vMAC2GLAddr($;$);
sub doConfigTN();
sub doConfigNUT();

%config = ();

$file = $ARGV[0];
$file = "config.in" if !defined($ARGV[0]);
$status = "";

# read from config.in
open (CONFIG, $file) || die "Cannot open $file: $!\n";

while (<CONFIG>) {
	if (/^#&\s*(.+)/) {
		$status .= $_;
		next;
	};

	if (/^#\s*(.+)/) {
		print "$1\n";
		$status .= $_;
	} elsif (/^\s*[\'\"]([^\'\"]+)[\'\"]\s+(\S+)\s+(\S+)\s+(\S+)/) {
		print "  - $1 ($2) : [$3] ";
		$desc = $1;
		$name = $2;
		$default = $3;
		$pattern = $4;
		do {
			$var = <STDIN>;
			chop($var);
			if ($var =~ /^\s*$/) {
				$config{$name} = $default;	# used default
			} elsif (!($var =~ /$pattern/)) {
				#print "    bad input '$var', must be '$pattern' format, please retry: ";
			} else {
				$config{$name} = $var;
			}
		} while (!(($var =~ /$pattern/) || ($var =~ /^\s*$/)));
		$status .= "\"$desc\"\t$name\t$config{$name}\t$pattern\n";
	} elsif (!(/^\s*$/)) {
		print "ERROR : Unknown line : '$_'";
		exit(1);
	} else {
		$status .= $_;
	}
}

close (CONFIG);

# write to config.status
open (CONFIG, ">config.status") || die "Cannot open $!\n";
print CONFIG $status;
close (CONFIG);

print "\n==== Start auto configue for test, please wait ====\n";
print "* Configure Tester Node (TN)\n";

print "  - Configure IP Address of $config{'interface00'}\n";
configInterfaceTN($config{'interface00'}, "192.168.0.19", "192.168.0.255", "255.255.255.0", "net0");

print "  - Restart Inteface $config{'interface00'}\n";
system("ifdown $config{'interface00'} && ifup $config{'interface00'}");

print "  - Configure IP Address of $config{'interface01'}\n";
configInterfaceTN($config{'interface01'}, "192.168.1.19", "192.168.1.255", "255.255.255.0", "net1");

print "  - Restart Inteface $config{'interface01'}\n";
system("ifdown $config{'interface01'} && ifup $config{'interface01'}");

print "  - Write Configure Information about the Tester Node (TN)\n";
doConfigTN();

$SimpleRemote::config{'System'} = $config{'System'};
$SimpleRemote::config{'User'} = $config{'User'};
$SimpleRemote::config{'Password'} = $config{'Password'};
$SimpleRemote::config{"RemoteDevice"} = $config{'RemoteDevice'};
print "\n* Configure Node Under Test (NUT)\n";

print "  - Configure IP Address of $config{'interface10'}\n";
configInterfaceNUT($config{'interface10'}, "192.168.0.21", "192.168.0.255", "255.255.255.0", "net0");

print "  - Restart Remote Inteface $config{'interface10'}\n";
rRemoteCommand("ifdown $config{'interface10'} && ifup $config{'interface10'}");

print "  - Configure IP Address of $config{'interface11'}\n";
configInterfaceNUT($config{'interface11'}, "192.168.1.21", "192.168.1.255", "255.255.255.0", "net1");

print "  - Restart Remote Inteface $config{'interface11'}\n";
rRemoteCommand("ifdown $config{'interface11'} && ifup $config{'interface11'}");

print "  - Write Configure Information about the Node Under Test (NUT)\n";
doConfigNUT();

print "* Configure Service of Remote System\n";
print "  - Disable Remote SELinux security policy\n";
doDisableSelinux();

print "  - Disable Remote Service which is not needed\n";
doDisableService();

print "  - Reboot Remote System\n";
vReboot();

print "\n=================== Configue Complete ===============\n\n";
print "*******************************************************\n";
print "** Now used 'pmake clean test' command to start test **\n";
print "*******************************************************\n\n";

sub configInterfaceTN($$$$;$) {
	my ($IF, $ip, $bcast, $netmask, $net) = @_;	 # MAC Address, NET

	$path = "/etc/sysconfig/network-scripts";
	if (! -e "$path/.ifcfg-$IF") {
		print "    old file is backup to $path/.ifcfg-$IF\n";
		system("cp $path/ifcfg-$IF $path/.ifcfg-$IF");
	}

	$file = "$path/ifcfg-$IF";
	$content = "";
	$mac = "";
	open (CONFIG, $file) || die "Cannot open $!\n";
	while (<CONFIG>) {
		if (/BOOTPROTO=\S+/) {
			$content .= "BOOTPROTO=static\n";
		} elsif (/ONBOOT=no/) {
			$content .= "ONBOOT=yes\n";
		} elsif (/IPADDR=\S+/
					|| /BORADCAST=\S+/
					|| /IPV6INIT=\S+/
					|| /IPV6ADDR=\S+/
					|| /NETMASK=\S+/) {
 		} elsif (/No\s+such\s+file\s+or\s+directory/) {
			print "ERROR: Maybe you does not has Interface $IF on TN\n";
			exit(1);
		} else {
			if (/HWADDR=(([0-9a-fA-F]{1,2}:){5}[0-9a-fA-F]{1,2})/) {
				$mac = $1;
			}
			$content .= $_;
		}
	}
	close (CONFIG);
	$content .= "IPADDR=$ip\n";
	$content .= "BORADCAST=$bcast\n";
	$content .= "NETMASK=$netmask\n";
	$content .= "IPV6INIT=yes\n";
	if ($mac eq "") {
		$mac = `ifconfig $IF | grep "HWaddr" | sed -e 's/^.*HWaddr //'`;
	}	
	$content .= "IPV6ADDR=".vMAC2GLAddr($mac, $net)."/64\n";

	open (CONFIG, ">$file") || die "Cannot open $!\n";
	print CONFIG $content;
	close (CONFIG);
}

sub configInterfaceNUT($$$$;$) {
	my ($IF, $ip, $bcast, $netmask, $net) = @_;	 # MAC Address, NET

	$path = "/etc/sysconfig/network-scripts";
	$from = "$path/ifcfg-$IF";
	$to = ".nut-ifcfg-$IF";
	rGetFile($from, $to);

	$content = "";
	$mac = "";
	open (CONFIG, $to) || die "Cannot open $!\n";
	while (<CONFIG>) {
		if (/BOOTPROTO=\S+/) {
			$content .= "BOOTPROTO=static\n";
		} elsif (/ONBOOT=no/) {
			$content .= "ONBOOT=yes\n";
		} elsif (/IPADDR=\S+/
					|| /BORADCAST=\S+/
					|| /IPV6INIT=\S+/
					|| /IPV6ADDR=\S+/
					|| /NETMASK=\S+/) {
 		} elsif (/No\s+such\s+file\s+or\s+directory/) {
			print "ERROR: Maybe you does not has Interface $IF on TN\n";
			exit(1);
		} else {
			if (/HWADDR=(([0-9a-fA-F]{1,2}:){5}[0-9a-fA-F]{1,2})/) {
				$mac = $1;
			}
			$content .= $_;
		}
	}
	close (CONFIG);
	$content .= "IPADDR=$ip\n";
	$content .= "BORADCAST=$bcast\n";
	$content .= "NETMASK=$netmask\n";
	$content .= "IPV6INIT=yes\n";
	if ($mac eq "") {
		$mac = getRemoteMAC($IF);
	}
	$config{"nutmac$IF"} = $mac;
	$content .= "IPV6ADDR=".vMAC2GLAddr($mac, $net)."/64\n";

	open (CONFIG, ">$to") || die "Cannot open $!\n";
	print CONFIG $content;
	close (CONFIG);
	rPutFile($to, $from);

	unlink($to);
}

sub getRemoteMAC($) {
	my ($IF) = @_;

	my $from = "/tmp/$IF.mac";
	my $cmd = "ifconfig $IF | grep \"HWaddr\" | sed -e \\\'s/^.*HWaddr //\\\' | tee $from";
	my $mac = "";
	rRemoteCommand($cmd);
	rGetFile($from, $from);
	open (CONFIG, $from) || die "Cannot open $!\n";
	while (<CONFIG>) {
		chop();
 		if (/No\s+such\s+file\s+or\s+directory/) {
			print "ERROR: Fail to Get Remote Interface 's MAC ADDR, please retry!\n";
			exit(1);
		}
		$mac .= $_;
	}
	close (CONFIG);
	return $mac;
}

sub vMAC2GLAddr($;$) { 
	my ($addr, $net) = @_;	 # MAC Address, NET

	my (@str, @hex);

	@str=split(/:/,$addr);
	foreach(@str) {
		push @hex,hex($_);
	};
	
	#
	# invert universal/local bit
	$hex[0] ^= 0x02;

	if ($net eq "net1") {
		sprintf "3ffe:501:ffff:101:%02x%02x:%02xff:fe%02x:%02x%02x",@hex;
	} else {
		sprintf "3ffe:501:ffff:100:%02x%02x:%02xff:fe%02x:%02x%02x",@hex;
	}
}

sub doConfigTN() {
	open (CONFIG, "../etc/tn.def.in") || die "Cannot open $!\n";
	open (CONFOUT, ">../etc/tn.def") || die "Cannot open $!\n";
	while (<CONFIG>) {
		if (/^(RemoteDevice)\s+(\S+)/) {
			$_ =~ s/$2/$config{'RemoteDevice'}/;
		} elsif (/^(Link0)\s+(\S+)\s+(([0-9a-fA-F]{1,2}:){5}[0-9a-fA-F]{1,2})/) {
			$_ =~ s/$2/$config{'interface00'}/;
		} elsif (/^(Link1)\s+(\S+)\s+(([0-9a-fA-F]{1,2}:){5}[0-9a-fA-F]{1,2})/) {
			$_ =~ s/$2/$config{'interface01'}/;
		}
		print CONFOUT $_;
	}
	close (CONFOUT);
	close (CONFIG);
}

sub doConfigNUT() {
	open (CONFIG, "../etc/nut.def.in") || die "Cannot open $!\n";
	open (CONFOUT, ">../etc/nut.def") || die "Cannot open $!\n";
	while (<CONFIG>) {
		if (/^(TargetName)\s+(\S+)/) {
			$_ =~ s/$2/$config{'TargetName'}/;
		} elsif (/^(HostName)\s+(\S+)/) {
			$_ =~ s/$2/$config{'HostName'}/;
		} elsif (/^(User)\s+(\S+)/) {
			$_ =~ s/$2/$config{'User'}/;
		} elsif (/^(Password)\s+(\S+)/) {
			$_ =~ s/$2/$config{'Password'}/;
		} elsif (/^(Link0)\s+(\S+)\s+(([0-9a-fA-F]{1,2}:){5}[0-9a-fA-F]{1,2})/) {
			$dev = $2;
			$mac = $3;
			$_ =~ s/$mac/$config{"nutmac".$config{'interface10'}}/;
			$_ =~ s/$dev/$config{'interface10'}/;
		} elsif (/^(Link1)\s+(\S+)\s+(([0-9a-fA-F]{1,2}:){5}[0-9a-fA-F]{1,2})/) {
			$dev = $2;
			$mac = $3;
			$_ =~ s/$mac/$config{"nutmac".$config{'interface11'}}/;
			$_ =~ s/$dev/$config{'interface11'}/;
		}
		print CONFOUT $_;
	}
	close (CONFOUT);
	close (CONFIG);	
}

sub doDisableSelinux() {
	my $from = "/etc/selinux/config";
	my $to = ".nut-config";
	my $content = "";

	rGetFile($from, $to);

	open (CONFIG, $to) || die "Cannot open $!\n";
	while (<CONFIG>) {
		if (/^\s*(SELINUX)\s*=\s*(\S+)/) {
			$_ =~ s/$2/disabled/;
		} elsif (/No\s+such\s+file\s+or\s+directory/) {
			print "WARN: Maybe you have not SELinux security policy install on NUT!\n";
			return 0;
		}
		$content .= $_;
	}
	close (CONFIG);

	open (CONFIG, ">$to") || die "Cannot open $!\n";
	print CONFIG $content;
	close (CONFIG);
	rPutFile($to, $from);
	unlink($to);
}

sub doDisableService() {
	my $from = "/tmp/.chkconfig";
	my $to = ".nut-chkconfig";
	my $content = "";
	my $cmd = "chkconfig --list | tee $from";
	my $allows = ":atd:echo:echo-udp:gpm:irqbalance:netfs:network:portmap:rawdevices:rhnsd:rsync:syslog:sshd:xfs:xinetd:";
	my $ignoreother = 0;
	my $notallows = ":avahi-daemon:ip6tables:iptables:vncserver:";

	rRemoteCommand($cmd);
	rGetFile($from, $to);

	$cmd = "";
	open (CONFIG, $to) || die "Cannot open $!\n";
	while (<CONFIG>) {
		if (/^\s*(\S+)\s+0:(\S+)\s+1:(\S+)\s+2:(\S+)\s+3:(\S+)\s+4:(\S+)\s+5:(\S+)\s+6:(\S+)\s+/) {
			if ($ignoreother == 0) {
				if (index($allows, ":$1:") != -1) {
					$cmd .= "chkconfig --level 3 $1 on && " if (lc($5) eq "off");
					$cmd .= "chkconfig --level 5 $1 on && " if (lc($7) eq "off");
				} else {
					$cmd .= "chkconfig --level 3 $1 off && " if (lc($5) eq "on");
					$cmd .= "chkconfig --level 5 $1 off && " if (lc($7) eq "on");
				}
			} else {
				if(index($notallows, ":$1:") != -1) {
					$cmd .= "chkconfig --level 3 $1 off && " if (lc($5) eq "on");
					$cmd .= "chkconfig --level 5 $1 off && " if (lc($7) eq "on");
				} elsif (index($allows, ":$1:") != -1) {
					$cmd .= "chkconfig --level 3 $1 on && " if (lc($5) eq "off");
					$cmd .= "chkconfig --level 5 $1 on && " if (lc($7) eq "off");
				}
			}
		} elsif (/No\s+such\s+file\s+or\s+directory/) {
			print "ERROR: Fail to Remote Service, please retry!\n";
			exit(1);
		}
		$content .= $_;
	}
	close (CONFIG);

	$cmd =~ s/&&\s*$//;
	if ($cmd ne "") {
		rRemoteCommand($cmd);	
	}

	unlink($to);
}
