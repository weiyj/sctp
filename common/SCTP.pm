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
########################################################################
package SCTP;

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
	vWarpRecv
	vWarpRecv2
	vWarpRecv3
	vRegisterExtNS
	vWarpCPP
	vListen
	vAccept
	vConnect
	vConnectAuth
	vRecvMsg
	vSendMsg
	vShutdown
	vClose
	sctpStartServer
	sctpStartClient
	sctpStartEchoServer
	sctpStartEchoClient
	sctpStartMultiHomeServer
	sctpStartMultiHomeClient
	sctpStartOptionServer
	sctpStartOptionClient
	sctpStartInteractiveServer
	sctpStatusServer
	sctpStatusClient
	sctpGetFieldName
	sctpMakeIPv6Address
	sctpFetchInitField
	sctpFetchAsconfField
	sctpFetchAuthShareKey
	sctpMakeAuthShareKey
	sctpUpdateSendTSN
	sctpUpdateRecvACK
	sctpMakeBadMD5Cookie
	sctpTimeFuzzyEqual
	sctpCheckEnv
	sctpPingToHost
	sctpPing6ToHost
	sctpGetFile
	sctpPutFile
	sctpGetMIBValue
	sctpGetRemoteSys
	sctpSetRemoteSys
	sctpGetRemoteStatus
	sctpPutAndCCFile
	sctpRemoteCommand
	sctpRemoteCommandAsync
	sctpRemoteCommandAsyncDelay
	sctpSystem
	sctpReboot
);

use V6evalTool;

#======================================================================
# vMAC2GLAddr - subroutine which makes globle address from EUI-64
#======================================================================
sub vMAC2GLAddr($;$) { 
	my ($addr, $net) = @_;	 # MAC Address, NET

	my (@str, @hex);

	@str=split(/:/,$addr);
	foreach(@str) {
		push @hex,hex($_);
	};
	
	# invert universal/local bit
	$hex[0] ^= 0x02;

	if ($net eq "net1") {
		sprintf "3ffe:501:ffff:101:%02x%02x:%02xff:fe%02x:%02x%02x",@hex;
	} else {
		sprintf "3ffe:501:ffff:100:%02x%02x:%02xff:fe%02x:%02x%02x",@hex;
	}
}

#======================================================================
# BEGIN - read sctpconf.def
#======================================================================
BEGIN {
	open (FILE, "../common/sctpconf.def") || die "Cannot open common/sctpconf.def: $!\n";
	while ( <FILE> ) {
		if ( /^#define\s+(\S+)\s+(\S+)/ ) {
			$CONF{$1} = $2;
		}
	}
	close FILE;

	#Used for global information
	$CONF{"NEEDREBOOT"} = 0;
	$CONF{"VERFTAG"} = 0xFFFFFFFF;
	#$CONF{"INITTAG"} = 0;
	$CONF{'SNDTSN'} = $CONF{"INITTSN"} - 1;
	$CONF{"SSERIAL"} = $CONF{"INITTSN"};
	$CONF{"SSRRSN"} = $CONF{"INITTSN"};
	%EXTNS = ();

	$CONF{"SCTP4_TN_NET0_ADDR"} =~ s/"//g;
	$CONF{"SCTP4_TN_NET1_ADDR"} =~ s/"//g;
	$CONF{"SCTP4_NUT_NET0_ADDR"} =~ s/"//g;
	$CONF{"SCTP4_NUT_NET1_ADDR"} =~ s/"//g;
	$CONF{"SCTP6_TN_NET0_ADDR"} = vMAC2GLAddr($V6evalTool::TnDef{"Link0_addr"});
	$CONF{"SCTP6_TN_NET1_ADDR"} = vMAC2GLAddr($V6evalTool::TnDef{"Link1_addr"}, "net1");
	$CONF{"SCTP6_NUT_NET0_ADDR"} = vMAC2GLAddr($V6evalTool::NutDef{"Link0_addr"});
	$CONF{"SCTP6_NUT_NET1_ADDR"} = vMAC2GLAddr($V6evalTool::NutDef{"Link1_addr"}, "net1");

	if ($CONF{ENABLE_IPV6} == 0) {
		$CONF{"SCTP_TN_NET0_ADDR"} = $CONF{"SCTP4_TN_NET0_ADDR"};
		$CONF{"SCTP_TN_NET1_ADDR"} = $CONF{"SCTP4_TN_NET1_ADDR"};
		$CONF{"SCTP_NUT_NET0_ADDR"} = $CONF{"SCTP4_NUT_NET0_ADDR"};
		$CONF{"SCTP_NUT_NET1_ADDR"} = $CONF{"SCTP4_NUT_NET1_ADDR"};
	} else {
		$CONF{"SCTP_TN_NET0_ADDR"} = $CONF{"SCTP6_TN_NET0_ADDR"};
		$CONF{"SCTP_TN_NET1_ADDR"} = $CONF{"SCTP6_TN_NET1_ADDR"};
		$CONF{"SCTP_NUT_NET0_ADDR"} = $CONF{"SCTP6_NUT_NET0_ADDR"};
		$CONF{"SCTP_NUT_NET1_ADDR"} = $CONF{"SCTP6_NUT_NET1_ADDR"};
	}

}

#======================================================================
# END - update port number
#======================================================================
END {
	# remember exit status, this maybe change after following process
	my $ret = $?;

	# update remote port
	$content = "";
	open (FILE, "../common/sctpconf.def") || die "Cannot open common/sctpconf.def: $!\n";
	while (<FILE>) {
		if (/^#define\s+SCTP_NUT0_PORT\s+(\S+)/) {
			$port = $1;
			$port++;
			$port = 3000 if ($port > 6000);
			$_ =~ s/$1/$port/;
		} elsif (/^#define\s+SCTP_TN0_PORT\s+(\S+)/) {
			$port = $1;
			$port++;
			$port = 2000 if ($port > 6000);
			$_ =~ s/$1/$port/;
		}
		$content .= $_;
	}
	close FILE;

	open (FILE, ">../common/sctpconf.def") || die "Cannot open common/sctpconf.def: $!\n";
	print FILE $content;
	close FILE;

	# Reboot Remote System if needed
	if ($CONF{"NEEDREBOOT"} != 0) {
		vLogHTML("<BR><B>== Need Reboot Remote System to restore Test Environment ==</B><BR>");
		sctpReboot();
#		sctpRemoteCommand("checksctp") if ($CONF{"NEEDREBOOT"} == 1);
	}

	# exit with the last exit status
	exit($ret);
}

#======================================================================
# vSetPktDesc - set pktdesc of arp or ns etc.
#======================================================================
sub vSetPktDesc() {
	$main::pktdesc{"arp_request_on_link0"} = "Recv ARP Request on Link0";
	$main::pktdesc{"arp_reply_on_link0"} = "Send ARP Reply on Link0";
	$main::pktdesc{"arp_request_on_link1"} = "Recv ARP Request on Link1";
	$main::pktdesc{"arp_reply_on_link1"} = "Send ARP Reply on Link1";
	$main::pktdesc{"ns_on_link0"} = "Recv Neighbor Solicitation on Link0 (Link Local)";
	$main::pktdesc{"na_on_link0"} = "Send Neighbor Advertisement on Link0 (Link Local)";
	$main::pktdesc{"ns_on_link1"} = "Recv Neighbor Solicitation on Link1 (Link Local)";
	$main::pktdesc{"na_on_link1"} = "Send Neighbor Advertisement on Link1 (Link Local)";
	$main::pktdesc{"ns_on_link0_gl"} = "Recv Neighbor Solicitation on Link0 (Global)";
	$main::pktdesc{"na_on_link0_gl"} = "Send Neighbor Advertisement on Link0 (Global)";
	$main::pktdesc{"ns_on_link1_gl"} = "Recv Neighbor Solicitation on Link1 (Global)";
	$main::pktdesc{"na_on_link1_gl"} = "Send Neighbor Advertisement on Link1 (Global)";

	foreach $ns (keys(%EXTNS)) {
		if ($CONF{ENABLE_IPV6} == 0 ) {
			$main::pktdesc{$ns} = "Recv ARP Request" if !defined($main::pktdesc{$ns});
			$main::pktdesc{$EXTNS{$ns}} = "Send ARP Reply" if !defined($main::pktdesc{$EXTNS{$ns}});
		} else {
			$main::pktdesc{$ns} = "Recv Neighbor Solicitation" if !defined($main::pktdesc{$ns});
			$main::pktdesc{$EXTNS{$ns}} = "Send Neighbor Advertisement" if !defined($main::pktdesc{$EXTNS{$ns}});
		}
	}

	$main::pktdesc{"sctp_chunk_init_snd"} = "Send SCTP CHUNK_INIT" if !defined($main::pktdesc{"sctp_chunk_init_snd"});
	$main::pktdesc{"sctp_chunk_init_auth_snd"} = "Send SCTP CHUNK_INIT" if !defined($main::pktdesc{"sctp_chunk_init_auth_snd"});
	$main::pktdesc{"sctp_chunk_init_rcv"} = "Recv SCTP CHUNK_INIT" if !defined($main::pktdesc{"sctp_chunk_init_rcv"});
	$main::pktdesc{"sctp_chunk_init_ack_snd"} = "Send SCTP CHUNK_INIT_ACK" if !defined($main::pktdesc{"sctp_chunk_init_ack_snd"});
	$main::pktdesc{"sctp_chunk_init_ack_rcv"} = "Recv SCTP CHUNK_INIT_ACK" if !defined($main::pktdesc{"sctp_chunk_init_ack_rcv"});
	$main::pktdesc{"sctp_chunk_cookie_echo_snd"} = "Send SCTP CHUNK_COOKIE_ECHO" if !defined($main::pktdesc{"sctp_chunk_cookie_echo_snd"});
	$main::pktdesc{"sctp_chunk_cookie_echo_rcv"} = "Recv SCTP CHUNK_COOKIE_ECHO" if !defined($main::pktdesc{"sctp_chunk_cookie_echo_rcv"});
	$main::pktdesc{"sctp_chunk_cookie_ack_snd"} = "Send SCTP CHUNK_COOKIE_ACK" if !defined($main::pktdesc{"sctp_chunk_cookie_ack_snd"});
	$main::pktdesc{"sctp_chunk_cookie_ack_rcv"} = "Recv SCTP CHUNK_COOKIE_ACK" if !defined($main::pktdesc{"sctp_chunk_cookie_ack_rcv"});
	$main::pktdesc{"sctp_chunk_data_snd"} = "Send SCTP CHUNK_DATA" if !defined($main::pktdesc{"sctp_chunk_data_snd"});
	$main::pktdesc{"sctp_chunk_data_rcv"} = "Recv SCTP CHUNK_DATA" if !defined($main::pktdesc{"sctp_chunk_data_rcv"});
	$main::pktdesc{"sctp_chunk_sack_snd"} = "Send SCTP CHUNK_SACK" if !defined($main::pktdesc{"sctp_chunk_sack_snd"});
	$main::pktdesc{"sctp_chunk_sack_rcv"} = "Recv SCTP CHUNK_SACK" if !defined($main::pktdesc{"sctp_chunk_sack_rcv"});
	$main::pktdesc{"sctp_chunk_shutdown_snd"} = "Send SCTP CHUNK_SHUTDOWN" if !defined($main::pktdesc{"sctp_chunk_shutdown_snd"});
	$main::pktdesc{"sctp_chunk_shutdown_rcv"} = "Recv SCTP CHUNK_SHUTDOWN" if !defined($main::pktdesc{"sctp_chunk_shutdown_rcv"});
	$main::pktdesc{"sctp_chunk_shutdown_ack_snd"} = "Send SCTP CHUNK_SHUTDOWN_ACK" if !defined($main::pktdesc{"sctp_chunk_shutdown_ack_snd"});
	$main::pktdesc{"sctp_chunk_shutdown_ack_rcv"} = "Recv SCTP CHUNK_SHUTDOWN_ACK" if !defined($main::pktdesc{"sctp_chunk_shutdown_ack_rcv"});
	$main::pktdesc{"sctp_chunk_shutdown_complete_snd"} = "Send SCTP CHUNK_SHUTDOWN_COMPLETE" if !defined($main::pktdesc{"sctp_chunk_shutdown_complete_snd"});
	$main::pktdesc{"sctp_chunk_shutdown_complete_rcv"} = "Recv SCTP CHUNK_SHUTDOWN_COMPLETE" if !defined($main::pktdesc{"sctp_chunk_shutdown_complete_rcv"});
	$main::pktdesc{"sctp_chunk_abort_snd"} = "Send SCTP CHUNK_ABORT" if !defined($main::pktdesc{"sctp_chunk_abort_snd"});
	$main::pktdesc{"sctp_chunk_abort_rcv"} = "Recv SCTP CHUNK_ABORT" if !defined($main::pktdesc{"sctp_chunk_abort_rcv"});
	$main::pktdesc{"sctp_chunk_any_rcv"} = "Recv SCTP CHUNK_ANY" if !defined($main::pktdesc{"sctp_chunk_any_rcv"});
}

#======================================================================
# vRegisterExtNS - Registe NA to reponse received NS
#======================================================================
sub vRegisterExtNS($$) {
	my ($ns, $na) = @_;

	$EXTNS{$ns} = $na;
}

#======================================================================
# vWarpRecv - warp of vRecv
#======================================================================
sub vWarpRecv($$$$@) {
	my ($ifname, $timeout, $seektime, $count, @frames) = @_;
	my $ns, $na, $ns_gl, $na_gl;
	my $stime = 0, $etime;

	$ifname = "Link0" if !defined($ifname);
	$ns = ($CONF{ENABLE_IPV6} == 1) ? "ns_on_".lc($ifname) : "arp_request_on_".lc($ifname);
	$na = ($CONF{ENABLE_IPV6} == 1) ? "na_on_".lc($ifname) : "arp_reply_on_".lc($ifname);
	$ns_gl = "ns_on_".lc($ifname)."_gl" if ($CONF{ENABLE_IPV6} == 1);
	$na_gl = "na_on_".lc($ifname)."_gl" if ($CONF{ENABLE_IPV6} == 1);

	vSetPktDesc();

	%ret = vRecv($ifname, $timeout, $seektime, $count, @frames, $ns, $ns_gl, keys(%EXTNS));
	while ($ret{recvFrame} eq $ns || (defined($ns_gl) && $ret{recvFrame} eq $ns_gl) || defined($EXTNS{$ret{recvFrame}})) {
		$etime = $ret{"recvTime".$ret{"recvCount"}};
		$stime = $ret{"recvTime1"} if ($stime == 0 && $ret{"recvCount"} > 1);
		if ($ret{recvFrame} eq $ns) {
			vSend($ifname, $na);
		} elsif (defined($ns_gl) && $ret{recvFrame} eq $ns_gl) {
			vSend($ifname, $na_gl);
		} else {
			vSend($ifname, $EXTNS{$ret{recvFrame}});
		}

		$timeout -= int($etime - $stime) if ($stime != 0);
		$timeout = 5 if($timeout < 0);
		$stime = $etime;
		%ret = vRecv($ifname, $timeout, $seektime, $count, @frames, $ns, $ns_gl, keys(%EXTNS));
	}

	return %ret;
}

#======================================================================
# vWarpRecv2 - warp of vRecv2
#======================================================================
sub vWarpRecv2($$$$@) {
	my ($ifname, $timeout, $seektime, $count, @frames) = @_;
	my $ns, $na, $ns_gl, $na_gl;
	my $stime = 0, $etime;

	$ifname = "Link0" if !defined($ifname);
	$ns = ($CONF{ENABLE_IPV6} == 1) ? "ns_on_".lc($ifname) : "arp_request_on_".lc($ifname);
	$na = ($CONF{ENABLE_IPV6} == 1) ? "na_on_".lc($ifname) : "arp_reply_on_".lc($ifname);
	$ns_gl = "ns_on_".lc($ifname)."_gl" if ($CONF{ENABLE_IPV6} == 1);
	$na_gl = "na_on_".lc($ifname)."_gl" if ($CONF{ENABLE_IPV6} == 1);

	vSetPktDesc();

	%ret = vRecv2($ifname, $timeout, $seektime, $count, @frames, $ns, $ns_gl, keys(%EXTNS));
	while ($ret{recvFrame} eq $ns || (defined($ns_gl) && $ret{recvFrame} eq $ns_gl) || defined($EXTNS{$ret{recvFrame}})) {
		$etime = $ret{"recvTime".$ret{"recvCount"}};
		$stime = $ret{"recvTime1"} if ($stime == 0 && $ret{"recvCount"} > 1);
		if ($ret{recvFrame} eq $ns) {
			vSend($ifname, $na);
		} elsif (defined($ns_gl) && $ret{recvFrame} eq $ns_gl) {
			vSend($ifname, $na_gl);
		} else {
			vSend($ifname, $EXTNS{$ret{recvFrame}});
		}

		$timeout -= int($etime - $stime) if ($stime != 0);
		$timeout = 5 if($timeout < 0);
		$stime = $etime;
		%ret = vRecv2($ifname, $timeout, $seektime, $count, @frames, $ns, $ns_gl, keys(%EXTNS));
	}

	return %ret;
}

#======================================================================
# vWarpRecv3 - warp of vRecv3
#======================================================================
sub vWarpRecv3($$$$@) {
	my ($ifname, $timeout, $seektime, $count, @frames) = @_;
	my $ns, $na, $ns_gl, $na_gl;
	my $stime = 0, $etime;

	$ifname = "Link0" if !defined($ifname);
	$ns = ($CONF{ENABLE_IPV6} == 1) ? "ns_on_".lc($ifname) : "arp_request_on_".lc($ifname);
	$na = ($CONF{ENABLE_IPV6} == 1) ? "na_on_".lc($ifname) : "arp_reply_on_".lc($ifname);
	$ns_gl = "ns_on_".lc($ifname)."_gl" if ($CONF{ENABLE_IPV6} == 1);
	$na_gl = "na_on_".lc($ifname)."_gl" if ($CONF{ENABLE_IPV6} == 1);

	vSetPktDesc();

	%ret = vRecv3($ifname, $timeout, $seektime, $count, @frames, $ns, $ns_gl, keys(%EXTNS));
	while ($ret{recvFrame} eq $ns || (defined($ns_gl) && $ret{recvFrame} eq $ns_gl) || defined($EXTNS{$ret{recvFrame}})) {
		$etime = $ret{"recvTime".$ret{"recvCount"}};
		$stime = $ret{"recvTime1"} if ($stime == 0 && $ret{"recvCount"} > 1);
		if ($ret{recvFrame} eq $ns) {
			vSend($ifname, $na);
		} elsif (defined($ns_gl) && $ret{recvFrame} eq $ns_gl) {
			vSend($ifname, $na_gl);
		} else {
			vSend($ifname, $EXTNS{$ret{recvFrame}});
		}

		$timeout -= int($etime - $stime) if ($stime != 0);
		$timeout = 5 if($timeout < 0);
		$stime = $etime;
		%ret = vRecv3($ifname, $timeout, $seektime, $count, @frames, $ns, $ns_gl, keys(%EXTNS));
	}

	return %ret;
}

#======================================================================
# vWarpCPP - warp of vCPP
#======================================================================
sub vWarpCPP(;@) {
	my (@opts) = @_; 		# pre-proceser options
	my $constant;

	$constant  = "-DINITTAG=$CONF{'INITTAG'} " if defined($CONF{'INITTAG'});
	$constant .= "-DVERFTAG=$CONF{'VERFTAG'} " if defined($CONF{'VERFTAG'});
	$constant .= "-DARWND=$CONF{'ARWND'} " if defined($CONF{'ARWND'});
	$constant .= "-DSNDTSN=$CONF{'SNDTSN'} " if defined($CONF{'SNDTSN'});
	$constant .= "-DSACK=$CONF{'SACK'} " if defined($CONF{'SACK'});	
	$constant .= "-DSSERIAL=$CONF{'SSERIAL'} " if defined($CONF{'SSERIAL'});
	$constant .= "-DRSERIAL=$CONF{'RSERIAL'} " if defined($CONF{'RSERIAL'});
	$constant .= "-DSSRRSN=$CONF{'SSRRSN'} " if defined($CONF{'SSRRSN'});
	$constant .= "-DRSRRSN=$CONF{'RSRRSN'} " if defined($CONF{'RSRRSN'});
	$constant .= "-DCOOKIE=hexstr\\\(\\\"$CONF{'COOKIE'}\\\"\\\) " if defined($CONF{'COOKIE'});
	$constant .= "-DADDIPRID=$CONF{'ADDIPRID'} " if defined($CONF{'ADDIPRID'});
	$constant .= "-DDATALEN=$CONF{'DATALEN'} " if defined($CONF{'DATALEN'});
	$constant .= "-DSCTP_TN0_PORT=$CONF{'SRCPORT'} " if defined($CONF{'SRCPORT'});
	$constant .= "-DSCTP_NUT0_PORT=$CONF{'DSTPORT'} " if defined($CONF{'DSTPORT'});
	$constant .= "-DAUTHSHAREKEY=\\\"$CONF{'AUTHSHAREKEY'}\\\" " if defined($CONF{'AUTHSHAREKEY'});

	vCPP($constant, @opts, $V6evalTool::CppOption);
}

#======================================================================
# sctpPingToHost - Ping to NUT
#======================================================================
sub sctpPingToHost(;$) {
	my ($IF) = @_;
	my $echo_request, $echo_reply, $arp_request, $arp_reply;

	$IF = "Link0" if !defined($IF);

	$main::pktdesc{"echo4_request_on_link0"} = "Send Echo Request on Link0";
	$main::pktdesc{"echo4_reply_on_link0"} = "Recv Echo Reply on Link0";
	$main::pktdesc{"echo4_request_on_link1"} = "Send Echo Request on Link1";
	$main::pktdesc{"echo4_reply_on_link1"} = "Recv Echo Reply on Link1";

	$echo_request = "echo4_request_on_" . lc($IF);
	$echo_reply = "echo4_reply_on_" . lc($IF);
	$arp_request = "arp_request_on_" . lc($IF);
	$arp_reply = "arp_reply_on_" . lc($IF);

	vLogTitle('============== sctpPingToHost ==============');

	vSend($IF, $echo_request);
	
	%ret = vRecv($IF, 5, 0, 0, $echo_reply, $arp_request);
	if ($ret{status} != 0) {
		vLogHTML('No response from NUT<BR>');
		vLogHTML('<FONT COLOR="#FF0000">NG</FONT>'); 
		exit $V6evalTool::exitFail;
	}

	if ($ret{recvFrame} eq $arp_request) {
		vSend($IF, $arp_reply);

		%ret = vRecv($IF, 5, 0, 0, $echo_reply);
		if ($ret{status} != 0) {
			vLogHTML('No response from NUT<BR>');
			vLogHTML('<FONT COLOR="#FF0000">NG</FONT>');
			exit $V6evalTool::exitFail;
		}
	}
	
	if ($ret{recvFrame} ne $echo_reply) {
		vLogHTML('Cannot receive Echo Reply<BR>');
		vLogHTML('<FONT COLOR="#FF0000">NG</FONT>');
		exit $V6evalTool::exitFail; 
	}
}

#======================================================================
# sctpPing6ToHost - Ping6 to NUT
#======================================================================
sub sctpPing6ToHost(;$) {
	my ($IF) = @_;
	my $echo_request, $echo_reply, $ns, $na, $ns_gl, $na_gl;

	$IF = "Link0" if !defined($ifname);

	$main::pktdesc{"echo_request_on_link0"} = "Send Echo Request on Link0";
	$main::pktdesc{"echo_reply_on_link0"} = "Recv Echo Reply on Link0";
	$main::pktdesc{"echo_request_on_link1"} = "Send Echo Request on Link1";
	$main::pktdesc{"echo_reply_on_link1"} = "Recv Echo Reply on Link1";

	$echo_request = "echo_request_on_" . lc($IF);
	$echo_reply = "echo_reply_on_" . lc($IF);
	$ns = "ns_on_" . lc($IF);
	$na = "na_on_" . lc($IF);
	$ns_gl = "ns_on_" . lc($IF) . "_gl";
	$na_gl = "na_on_" . lc($IF) . "_gl";

	vLogTitle('============= sctpPing6ToHost ==============');

	vSend($IF, $echo_request);

	%ret = vRecv($IF, 5, 0, 0, $echo_reply, $ns, $ns_gl);
	if ($ret{status} != 0) {
		vLogHTML('No response from NUT<BR>');
		vLogHTML('<FONT COLOR="#FF0000">NG</FONT>'); 
		exit $V6evalTool::exitFail;
	}
	
	if ($ret{recvFrame} eq $ns || $ret{recvFrame} eq $ns_gl) {
		if ($ret{recvFrame} eq $ns_gl) {
			vSend($IF, $na_gl);
		} else {
			vSend($IF, $na);
		}

		%ret = vRecv($IF, 5, 0, 0, $echo_reply);
		if ($ret{status} != 0) {
			vLogHTML('No response from NUT<BR>');
			vLogHTML('<FONT COLOR="#FF0000">NG</FONT>');
			exit $V6evalTool::exitFail;
		}
	}
	
	if ($ret{recvFrame} ne $echo_reply) {
		vLogHTML('Cannot receive Echo Reply<BR>');
		vLogHTML('<FONT COLOR="#FF0000">NG</FONT>');
		exit $V6evalTool::exitFail; 
	}
}

#======================================================================
# sctpCheckEnv - check Link0 and Link1 of NUT reachable
#======================================================================
sub sctpCheckEnv(;$$) {
	my ($IF0, $IF1) = @_;

	$IF0 = "Link0" if !defined($IF0);

	vLogTitle('=============== sctpCheckEnv ===============');

	sctpRemoteCommand("killall -9 sctp_test ; killall -9 sctp_darn ; killall -9 sctp_status; checksctp");

	vSetPktDesc();

	if ($CONF{ENABLE_IPV6} == 1) {
		sctpPing6ToHost($IF0);
		sctpPing6ToHost($IF1) if defined($IF1);
	} else {
		sctpPingToHost($IF0);
		sctpPingToHost($IF1) if defined($IF1);
	}
}

#======================================================================
# sctpGetFieldName - 
#======================================================================
sub sctpGetFieldName($;$) {
	my ($field, $usedipv6) = @_;

	$usedipv6 = $CONF{ENABLE_IPV6} if !defined($usedipv6);

	if($usedipv6 == 0 ) {
		return "Frame_Ether.Packet_IPv4.Upp_SCTP." . $field;
	} else {
		return "Frame_Ether.Packet_IPv6.Upp_SCTP." . $field;
	}
}

#======================================================================
# sctpMakeIPv6Address - makes address from EUI-64
#======================================================================
sub sctpMakeIPv6Address($$) { 
	my ($prefix, $mac) = @_;	 # Prefix, MAC Address
	my (@str, @hex);

	@str=split(/:/, $mac);
	foreach(@str) {
		push @hex,hex($_);
	};

	# invert universal/local bit
	$hex[0] ^= 0x02;

	sprintf "$prefix:%02x%02x:%02xff:fe%02x:%02x%02x", @hex;
}

#======================================================================
# sctpFetchInitField - 
#======================================================================
sub sctpFetchInitField($) {
	my ($ret) = @_;

	if (defined($$ret{sctpGetFieldName("CHUNK_INIT")})) {
		$CONF{'VERFTAG'} = $$ret{sctpGetFieldName("CHUNK_INIT.InitiateTag")};
		$CONF{'ARWND'} = $$ret{sctpGetFieldName("CHUNK_INIT.AdvRecvWindow")};
		$CONF{'SACK'} = $$ret{sctpGetFieldName("CHUNK_INIT.TSN")} - 1;
		$CONF{'RSERIAL'} = $$ret{sctpGetFieldName("CHUNK_INIT.TSN")};
		$CONF{'RSRRSN'} = $$ret{sctpGetFieldName("CHUNK_INIT.TSN")};
	} elsif (defined($$ret{sctpGetFieldName("CHUNK_INIT_ACK")})) {
		$CONF{'VERFTAG'} = $$ret{sctpGetFieldName("CHUNK_INIT_ACK.InitiateTag")};
		$CONF{'COOKIE'} = $$ret{sctpGetFieldName("CHUNK_INIT_ACK.StaleCookie.Cookie")};
		$CONF{'COOKIE'} =~ s/\n//;
		$CONF{'ARWND'} = $$ret{sctpGetFieldName("CHUNK_INIT_ACK.AdvRecvWindow")};
		$CONF{'SACK'} = $$ret{sctpGetFieldName("CHUNK_INIT_ACK.TSN")} - 1;
		$CONF{'RSERIAL'} = $$ret{sctpGetFieldName("CHUNK_INIT_ACK.TSN")};
		$CONF{'RSRRSN'} = $$ret{sctpGetFieldName("CHUNK_INIT_ACK.TSN")};
	}

	vWarpCPP();
}

#======================================================================
# sctpFetchAsconfField - Fetch RequestID from ASCONF or ASCONF-ACK chunk
#======================================================================
sub sctpFetchAsconfField($) {
	my ($ret) = @_;

	if (defined($$ret{sctpGetFieldName("CHUNK_ASCONF.AddIPAddress")})) {
		$CONF{'ADDIPRID'} = $$ret{sctpGetFieldName("CHUNK_ASCONF.AddIPAddress.RequestID")};
	} elsif (defined($$ret{sctpGetFieldName("CHUNK_ASCONF.DeleteIPAddress")})) {
		$CONF{'ADDIPRID'} = $$ret{sctpGetFieldName("CHUNK_ASCONF.DeleteIPAddress.RequestID")};
	} elsif (defined($$ret{sctpGetFieldName("CHUNK_ASCONF.SetPrimaryAddress")})) {
		$CONF{'ADDIPRID'} = $$ret{sctpGetFieldName("CHUNK_ASCONF.SetPrimaryAddress.RequestID")};
	} elsif (defined($$ret{sctpGetFieldName("CHUNK_ASCONF_ACK.SuccessIndication")})) {
		$CONF{'ADDIPRID'} = $$ret{sctpGetFieldName("CHUNK_ASCONF_ACK.SuccessIndication.RequestID")};
	} elsif (defined($$ret{sctpGetFieldName("CHUNK_ASCONF_ACK.ErrorCauseIndication")})) {
		$CONF{'ADDIPRID'} = $$ret{sctpGetFieldName("CHUNK_ASCONF_ACK.ErrorCauseIndication.RequestID")};
	}

	vWarpCPP();
}

#======================================================================
# sctpFetchAuthShareKey - Fetch the Auth Share Key from init chunk
#======================================================================
sub sctpFetchAuthShareKey($) {
	my ($ret) = @_;
	my $key = "";
	my $name, $type, $len, $value, $item;

	# Random + chunks + hmac
	if (defined($$ret{sctpGetFieldName("CHUNK_INIT")})) {
		$name = sctpGetFieldName("CHUNK_INIT");
	} elsif (defined($$ret{sctpGetFieldName("CHUNK_INIT_ACK")})) {
		$name = sctpGetFieldName("CHUNK_INIT_ACK");
	} else {
		return;
	}

	return if (!defined($$ret{"$name.Random"}));

	# encode Random paramter
	$type = $$ret{"$name.Random.Type"};
	$len = $$ret{"$name.Random.Length"};
	$value = $$ret{"$name.Random.RandomNumber"};
	$key = sprintf "%04x%04x%s", $type, $len, $value;

	# encode ChunkList paramter withour padding
	if (defined($$ret{"$name.ChunkList"})) {
		$type = $$ret{"$name.ChunkList.Type"};
		$len = $$ret{"$name.ChunkList.Length"};
		$key .= sprintf "%04x%04x", $type, $len;
		foreach $item (split(' ', $$ret{"$name.ChunkList"})) {
			if ($item =~ /ChunkType/) {
				$key .= sprintf "%02x", $$ret{"$name.ChunkList.$item"};
			}
		}
	}

	return if (!defined($$ret{"$name.RequestedHMACAlgorithm"}));

	# encode RequestedHMACAlgorithm paramter withour padding
	$type = $$ret{"$name.RequestedHMACAlgorithm.Type"};
	$len = $$ret{"$name.RequestedHMACAlgorithm.Length"};
	$key .= sprintf "%04x%04x", $type, $len;
	foreach $item (split(' ', $$ret{"$name.RequestedHMACAlgorithm"})) {
		if ($item =~ /HMACIdentifier/) {
			$key .= sprintf "%04x", $$ret{"$name.RequestedHMACAlgorithm.$item"};
		}
	}

	if (defined($$ret{sctpGetFieldName("CHUNK_INIT")})) {
		$CONF{'LAUTHKEY'} = $key;
	} elsif (defined($$ret{sctpGetFieldName("CHUNK_INIT_ACK")})) {
		$CONF{'RAUTHKEY'} = $key;
	}

	return $key;
}

#======================================================================
# sctpMakeAuthShareKey - Make the Auth share key
#======================================================================
sub sctpMakeAuthShareKey(;$$) {
	my ($lkey, $rkey) = @_;

	$lkey = $CONF{'LAUTHKEY'} if (!defined($lkey));
	$rkey = $CONF{'RAUTHKEY'} if (!defined($rkey));

	return if (!defined($lkey) || !defined($rkey));

	if (length($lkey) > length($rkey)) {
		$CONF{'AUTHSHAREKEY'} = $rkey . $lkey;
	} elsif (length($lkey) < length($rkey)) {
		$CONF{'AUTHSHAREKEY'} = $lkey . $rkey;
	} elsif (($lkey cmp $rkey) < 0) {
		$CONF{'AUTHSHAREKEY'} = $lkey . $rkey;
	} else {
		$CONF{'AUTHSHAREKEY'} = $rkey . $lkey;
	}

	return $CONF{'AUTHSHAREKEY'};
}

#======================================================================
# vListen - do listen as sctp server
#======================================================================
sub vListen($;$$) {
	my ($IF, $init, $init_ack) = @_;

	$IF = "Link0" if !defined($IF);
	$init = 'sctp_chunk_init_rcv' if !defined($init);
	$init_ack = 'sctp_chunk_init_ack_snd' if !defined($init_ack);

	vLogTitle('================= vListen ==================');

	%ret = vWarpRecv3($IF, 10, 0, 0, $init);
	if($ret{status} != 0 || $ret{recvFrame} ne $init) {
		vLogHTML('Cannot receive SCTP CHUNK_INIT<BR>');
		vSend($IF, sctp_chunk_abort_snd);
		vLogHTML('<FONT COLOR="#FF0000">NG</FONT>'); 
		exit $V6evalTool::exitFail;
	}

	sctpFetchAuthShareKey(\%ret);

	$CONF{'VERFTAG'} = $ret{sctpGetFieldName("CHUNK_INIT.InitiateTag")};
	$CONF{'SACK'} = $ret{sctpGetFieldName("CHUNK_INIT.TSN")} - 1;
	$CONF{'RSERIAL'} = $ret{sctpGetFieldName("CHUNK_INIT.TSN")};
	$CONF{'RSRRSN'} = $ret{sctpGetFieldName("CHUNK_INIT.TSN")};
	$CONF{'ARWND'} = $ret{sctpGetFieldName("CHUNK_INIT.AdvRecvWindow")};
	vWarpCPP();
	%ret = vSend3($IF, $init_ack);

	sctpFetchAuthShareKey(\%ret);
	sctpMakeAuthShareKey();

	return %ret;
}

#======================================================================
# vAccept - do accept as sctp server
#======================================================================
sub vAccept($;$$) {
	my ($IF, $cookie_echo, $cookie_ack) = @_;

	$IF = "Link0" if !defined($IF);
	$cookie_echo = 'sctp_chunk_cookie_echo_rcv' if !defined($cookie_echo);
	$cookie_ack = 'sctp_chunk_cookie_ack_snd' if !defined($cookie_ack);

	vLogTitle('================= vAccept ==================');

	%ret = vWarpRecv($IF, 10, 0, 0, $cookie_echo);
	if($ret{status} != 0 || $ret{recvFrame} ne $cookie_echo) {
		vLogHTML('Cannot receive SCTP CHUNK_COOKIE_ECHO<BR>');
		vSend($IF, sctp_chunk_abort_snd);
		vLogHTML('<FONT COLOR="#FF0000">NG</FONT>'); 
		exit $V6evalTool::exitFail;
	}

	%ret = vSend($IF, $cookie_ack);

	return %ret;
}

#======================================================================
# vConnect - do connect as sctp client 
#======================================================================
sub vConnect($;$$$$) {
	my ($IF, $init, $init_ack, $cookie_echo, $cookie_ack) = @_;

	$IF = "Link0" if !defined($IF);
	$init = 'sctp_chunk_init_snd' if !defined($init);
	$init_ack = 'sctp_chunk_init_ack_rcv' if !defined($init_ack);
	$cookie_echo = 'sctp_chunk_cookie_echo_snd' if !defined($cookie_echo);
	$cookie_ack = 'sctp_chunk_cookie_ack_rcv' if !defined($cookie_ack);

	vLogTitle('================= vConnect =================');

	%ret = vSend3($IF, $init);
	sctpFetchAuthShareKey(\%ret);

	%ret = vWarpRecv3($IF, 10, 0, 0, $init_ack);
	if($ret{status} != 0 || $ret{recvFrame} ne $init_ack) {
		vLogHTML('Cannot receive SCTP CHUNK_INIT_ACK<BR>');
		vSend($IF, sctp_chunk_abort_snd);
		vLogHTML('<FONT COLOR="#FF0000">NG</FONT>'); 
		exit $V6evalTool::exitFail;
	}

	sctpFetchAuthShareKey(\%ret);
	sctpMakeAuthShareKey();

	$CONF{'VERFTAG'} = $ret{sctpGetFieldName("CHUNK_INIT_ACK.InitiateTag")};
	$CONF{'COOKIE'} = $ret{sctpGetFieldName("CHUNK_INIT_ACK.StaleCookie.Cookie")};
	$CONF{'COOKIE'} =~ s/\n//;
	$CONF{'ARWND'} = $ret{sctpGetFieldName("CHUNK_INIT_ACK.AdvRecvWindow")};
	$CONF{'SACK'} = $ret{sctpGetFieldName("CHUNK_INIT_ACK.TSN")} - 1;
	$CONF{'RSERIAL'} = $ret{sctpGetFieldName("CHUNK_INIT_ACK.TSN")};
	$CONF{'RSRRSN'} = $ret{sctpGetFieldName("CHUNK_INIT_ACK.TSN")};
	vWarpCPP();

	vSend($IF, $cookie_echo);

	%ret = vWarpRecv2($IF, 10, 0, 0, $cookie_ack);
	if($ret{status} != 0 || $ret{recvFrame} ne $cookie_ack) {
		vLogHTML('Cannot receive SCTP CHUNK_COOKIE_ACK<BR>');
		vSend($IF, sctp_chunk_abort_snd);
		vLogHTML('<FONT COLOR="#FF0000">NG</FONT>'); 
		exit $V6evalTool::exitFail;
	}

	return %ret;
}

#======================================================================
# vConnectAuth - do connect as sctp client with AUTH support
#======================================================================
sub vConnectAuth($;$$$$) {
	my ($IF, $init, $init_ack, $cookie_echo, $cookie_ack) = @_;

	$IF = "Link0" if !defined($IF);
	$init = 'sctp_chunk_init_auth_snd' if !defined($init);
	$init_ack = 'sctp_chunk_init_ack_rcv' if !defined($init_ack);
	$cookie_echo = 'sctp_chunk_cookie_echo_snd' if !defined($cookie_echo);
	$cookie_ack = 'sctp_chunk_cookie_ack_rcv' if !defined($cookie_ack);

	vLogTitle('=============== vConnectAuth ===============');

	%ret = vSend3($IF, $init);
	$CONF{'SNDTSN'} = $ret{sctpGetFieldName("CHUNK_INIT.TSN")} - 1;
	$CONF{"SSERIAL"} = $ret{sctpGetFieldName("CHUNK_INIT.TSN")};
	sctpFetchAuthShareKey(\%ret);

	%ret = vWarpRecv3($IF, 10, 0, 0, $init_ack);
	if($ret{status} != 0 || $ret{recvFrame} ne $init_ack) {
		vLogHTML('Cannot receive SCTP CHUNK_INIT_ACK<BR>');
		vSend($IF, sctp_chunk_abort_snd);
		vLogHTML('<FONT COLOR="#FF0000">NG</FONT>'); 
		exit $V6evalTool::exitFail;
	}

	sctpFetchAuthShareKey(\%ret);
	sctpMakeAuthShareKey();

	$CONF{'VERFTAG'} = $ret{sctpGetFieldName("CHUNK_INIT_ACK.InitiateTag")};
	$CONF{'COOKIE'} = $ret{sctpGetFieldName("CHUNK_INIT_ACK.StaleCookie.Cookie")};
	$CONF{'COOKIE'} =~ s/\n//;
	$CONF{'ARWND'} = $ret{sctpGetFieldName("CHUNK_INIT_ACK.AdvRecvWindow")};
	$CONF{'SACK'} = $ret{sctpGetFieldName("CHUNK_INIT_ACK.TSN")} - 1;
	$CONF{'RSERIAL'} = $ret{sctpGetFieldName("CHUNK_INIT_ACK.TSN")};
	$CONF{'RSRRSN'} = $ret{sctpGetFieldName("CHUNK_INIT_ACK.TSN")};
	vWarpCPP();

	vSend($IF, $cookie_echo);

	%ret = vWarpRecv2($IF, 10, 0, 0, $cookie_ack);
	if($ret{status} != 0 || $ret{recvFrame} ne $cookie_ack) {
		vLogHTML('Cannot receive SCTP CHUNK_COOKIE_ACK<BR>');
		vSend($IF, sctp_chunk_abort_snd);
		vLogHTML('<FONT COLOR="#FF0000">NG</FONT>'); 
		exit $V6evalTool::exitFail;
	}

	return %ret;
}

#======================================================================
# vRecvMsg - receive a data segment
#======================================================================
sub vRecvMsg($;$$) {
	my ($IF, $data, $sack) = @_;

	$IF = "Link0" if !defined($IF);
	$data = 'sctp_chunk_data_rcv' if !defined($data);
	$sack = 'sctp_chunk_sack_snd' if !defined($sack);

	vLogTitle('================= vRecvMsg =================');

	sctpUpdateRecvACK();

	%ret = vWarpRecv($IF, 10, 0, 0, $data);
	if($ret{status} != 0 || $ret{recvFrame} ne $data) {
		vLogHTML('Cannot receive SCTP CHUNK_DATA<BR>');
		vSend($IF, sctp_chunk_abort_snd);
		vLogHTML('<FONT COLOR="#FF0000">NG</FONT>'); 
		exit $V6evalTool::exitFail;
	}

	%ret = vSend($IF, $sack);

	return %ret;
}

#======================================================================
# vSendMsg - send a data segment
#======================================================================
sub vSendMsg($;$$) {
	my ($IF, $data, $sack) = @_;

	$IF = "Link0" if !defined($IF);
	$data = 'sctp_chunk_data_snd' if !defined($data);
	$sack = 'sctp_chunk_sack_rcv' if !defined($sack);

	vLogTitle('================= vSendMsg =================');

	sctpUpdateSendTSN();

	vSend($IF, $data);

	%ret = vWarpRecv($IF, 10, 0, 0, $sack);
	if($ret{status} != 0 || $ret{recvFrame} ne $sack) {
		vLogHTML('Cannot receive SCTP CHUNK_SACK<BR>');
		vSend($IF, sctp_chunk_abort_snd);
		vLogHTML('<FONT COLOR="#FF0000">NG</FONT>'); 
		exit $V6evalTool::exitFail;
	}

	return %ret;
}

#======================================================================
# vShutdown - shutdown sctp connect
#======================================================================
sub vShutdown($;$$$$) {
	my ($IF, $sack, $shutdown, $shutdown_ack, $shutdown_complete) = @_;

	$IF = "Link0" if !defined($IF);
	$shutdown = 'sctp_chunk_shutdown_rcv' if !defined($shutdown);
	$shutdown_ack = 'sctp_chunk_shutdown_ack_snd' if !defined($shutdown_ack);
	$shutdown_complete = 'sctp_chunk_shutdown_complete_rcv' if !defined($shutdown_complete);
	undef($sack) if (defined($sack) && $sack eq "");

	my $recvsack = 0;

	vLogTitle('================ vShutdown =================');

	%ret = vWarpRecv($IF, 10, 0, 0, $shutdown, $sack);
	if(defined($sack) && $ret{recvFrame} eq $sack) {
		$recvsack = 1;
		%ret = vWarpRecv($IF, 30, 0, 0, $shutdown);
	}

	if($ret{status} != 0 || $ret{recvFrame} ne $shutdown) {
		vLogHTML('Cannot receive SCTP CHUNK_SHUTDOWN<BR>');
		vSend($IF, sctp_chunk_abort_snd);
		vLogHTML('<FONT COLOR="#FF0000">NG</FONT>'); 
		exit $V6evalTool::exitFail;
	}

	if(defined($sack) && !$recvsack) {
		%ret = vWarpRecv($IF, 10, 0, 0, $sack);
		if($ret{status} != 0 || $ret{recvFrame} ne $sack) {
			vLogHTML('Cannot receive SCTP CHUNK_SACK<BR>');
			vSend($IF, sctp_chunk_abort_snd);
			vLogHTML('<FONT COLOR="#FF0000">NG</FONT>'); 
			exit $V6evalTool::exitFail;
		}
	}

	vSend($IF, $shutdown_ack);

	%ret = vWarpRecv($IF, 10, 0, 0, $shutdown_complete);
	if($ret{status} != 0 || $ret{recvFrame} ne $shutdown_complete) {
		vLogHTML('Cannot receive SCTP CHUNK_SHUTDOWN_COMPLETE<BR>');
		vSend($IF, sctp_chunk_abort_snd);
		vLogHTML('<FONT COLOR="#FF0000">NG</FONT>'); 
		exit $V6evalTool::exitFail;
	}

	return %ret;
}

#======================================================================
# vClose - close sctp connect
#======================================================================
sub vClose($;$$$) {
	my ($IF, $shutdown, $shutdown_ack, $shutdown_complete) = @_;

	$IF = "Link0" if !defined($IF);
	$shutdown = 'sctp_chunk_shutdown_snd' if !defined($shutdown);
	$shutdown_ack = 'sctp_chunk_shutdown_ack_rcv' if !defined($shutdown_ack);
	$shutdown_complete = 'sctp_chunk_shutdown_complete_snd' if !defined($shutdown_complete);

	vLogTitle('================== vClose ==================');

	vSend($IF, $shutdown);

	%ret = vWarpRecv($IF, 10, 0, 0, $shutdown_ack);
	if($ret{status} != 0 || $ret{recvFrame} ne $shutdown_ack) {
		vLogHTML('Cannot receive SCTP CHUNK_SHUTDOWN_ACK<BR>');
		vSend($IF, sctp_chunk_abort_snd);
		vLogHTML('<FONT COLOR="#FF0000">NG</FONT>'); 
		exit $V6evalTool::exitFail;
	}

	%ret = vSend($IF, $shutdown_complete);

	return %ret;
}

#======================================================================
# sctpUpdateSendTSN - update local system's TSN
#======================================================================
sub sctpUpdateSendTSN(;$) {
	my ($inc) = @_;

	$inc = 1 if !defined($inc);
	if (defined($CONF{'SNDTSN'})) {
		$CONF{'SNDTSN'} += $inc;
		vWarpCPP();
	}
}

#======================================================================
# sctpUpdateRecvACK - update remote system's TSN 
#======================================================================
sub sctpUpdateRecvACK(;$) {
	my ($inc) = @_;

	$inc = 1 if !defined($inc);
	if (defined($CONF{'SACK'})) {
		$CONF{'SACK'} += $inc;
		vWarpCPP();
	}
}

#======================================================================
# sctpStartClient - start a sctp client at remote system
#======================================================================
sub sctpStartClient(;$$$$) {
	my ($IF, $count, $size, $opts) = @_;
	my ($cmd);

	$IF = "Link0" if !defined($IF);
	$count = 1 if !defined($count);
	if (!defined($size)) {
		$size = $CONF{"DEFAULT_DATA_LEN"};
	} else {
		$CONF{"DATALEN"} = $size;
	}

	vLogTitle('============== sctpStartClient =============');

	$cmd  = "sctp_test ";
	$cmd .= "-H $CONF{SCTP_NUT_NET0_ADDR} -P $CONF{SCTP_NUT0_PORT} ";
	$cmd .= "-h $CONF{SCTP_TN_NET0_ADDR} -p $CONF{SCTP_TN0_PORT} ";
	$cmd .= "-T -s -c -$size -X 1 -x $count ";
	$cmd .= "-o 1 ";
	$cmd .= $opts if defined($opts);
	$cmd .= " &";

	sctpRemoteCommandAsyncDelay($cmd);
}

#======================================================================
# sctpStartServer - start a sctp server at remote system
# $count does not support now
#======================================================================
sub sctpStartServer(;$$$) {
	my ($IF, $count, $opts) = @_;
	my ($cmd);

	$IF = "Link0" if !defined($IF);
	$count = 1 if !defined($count);

	vLogTitle('============== sctpStartServer =============');

	$cmd  = "sctp_test ";
	$cmd .= "-H $CONF{SCTP_NUT_NET0_ADDR} -P $CONF{SCTP_NUT0_PORT} ";
	$cmd .= "-T -l -x 1 -X $count ";
	$cmd .= $opts if defined($opts);
	$cmd .= " &";

	sctpRemoteCommandAsync($cmd);
}

#======================================================================
# sctpStartMultiHomeServer - start a sctp multi-home server at remote system
#======================================================================
sub sctpStartMultiHomeServer(;$$$) {
	my ($IF, $count, $opts) = @_;
	my ($cmd);

	$IF = "Link0" if !defined($IF);
	$count = 1 if !defined($count);

	vLogTitle('========= sctpStartMultiHomeServer =========');

	$cmd  = "sctp_test ";
	$cmd .= "-H $CONF{SCTP_NUT_NET0_ADDR} -B $CONF{SCTP_NUT_NET1_ADDR} ";
	$cmd .= "-P $CONF{SCTP_NUT0_PORT} ";
	$cmd .= "-T -l -x 1 -X $count ";
	$cmd .= $opts if defined($opts);
	$cmd .= " &";

	sctpRemoteCommandAsync($cmd);
}

#======================================================================
# sctpStartMultiHomeClient - start a sctp multi-home client at remote system
#======================================================================
sub sctpStartMultiHomeClient(;$$) {
	my ($IF, $count, $size, $opts) = @_;
	my ($cmd);

	$IF = "Link0" if !defined($IF);
	$count = 1 if !defined($count);
	if (!defined($size)) {
		$size = $CONF{"DEFAULT_DATA_LEN"};
	} else {
		$CONF{"DATALEN"} = $size;
	}

	vLogTitle('========= sctpStartMultiHomeClient =========');

	$cmd  = "sctp_test ";
	$cmd .= "-H $CONF{SCTP_NUT_NET0_ADDR} -B $CONF{SCTP_NUT_NET1_ADDR} ";
	$cmd .= "-C $CONF{SCTP_TN_NET0_ADDR} -C $CONF{SCTP_TN_NET1_ADDR} ";
	$cmd .= "-P $CONF{SCTP_NUT0_PORT} -p $CONF{SCTP_TN0_PORT} ";
	$cmd .= "-T -s -c -$size -X 1 -x $count ";
	$cmd .= "-o 1 ";
	$cmd .= $opts if defined($opts);
	$cmd .= " &";

	sctpRemoteCommandAsyncDelay($cmd);
}

#======================================================================
# sctpStartEchoClient - start a sctp echo-client at remote system
#======================================================================
sub sctpStartEchoClient(;$$$$) {
	my ($IF, $count, $size, $opts) = @_;
	my ($cmd);

	$IF = "Link0" if !defined($IF);
	$count = 1 if !defined($count);
	if (!defined($size)) {
		$size = $CONF{"DEFAULT_DATA_LEN"};
	} else {
		$CONF{"DATALEN"} = $size;
	}

	vLogTitle('============== sctpStartClient =============');

	$cmd  = "sctp_test ";
	$cmd .= "-H $CONF{SCTP_NUT_NET0_ADDR} -P $CONF{SCTP_NUT0_PORT} ";
	$cmd .= "-h $CONF{SCTP_TN_NET0_ADDR} -p $CONF{SCTP_TN0_PORT} ";
	$cmd .= "-T -s -c -$size -X 1 -x $count ";
	$cmd .= "-o 1 -D ";
	$cmd .= $opts if defined($opts);
	$cmd .= " &";

	sctpRemoteCommandAsyncDelay($cmd);
}

#======================================================================
# sctpStartEchoServer - start a sctp echo-server at remote system
#======================================================================
sub sctpStartEchoServer(;$$) {
	my ($IF, $opts) = @_;
	my ($cmd);

	$IF = "Link0" if !defined($IF);

	vLogTitle('============ sctpStartEchoServer ===========');

	$cmd  = "sctp_darn ";
	$cmd .= "-H $CONF{SCTP_NUT_NET0_ADDR} -P $CONF{SCTP_NUT0_PORT} ";
	$cmd .= "-l -t -e ";
	$cmd .= $opts if defined($opts);
	$cmd .= " &";

	sctpRemoteCommandAsync($cmd);
}

#======================================================================
# sctpStartOptionClient - start a sctp client with option at remote system
#======================================================================
sub sctpStartOptionClient(;$$) {
	my ($IF, $opts) = @_;
	my ($cmd);

	$IF = "Link0" if !defined($IF);

	vLogTitle('=========== sctpStartOptionClient ==========');

	$cmd  = "sctp_darn ";
	$cmd .= "-H $CONF{SCTP_NUT_NET0_ADDR} -P $CONF{SCTP_NUT0_PORT} ";
	$cmd .= "-h $CONF{SCTP_TN_NET0_ADDR} " if (!defined($opts) || $opts =~ /'-c'/ || $opts =~ /'--connectx'/);
	$cmd .= "-p $CONF{SCTP_TN0_PORT} -s ";
	$cmd .= $opts if defined($opts);
	$cmd .= " &";

	vRemote("rcommandasync.rmt", "cmd=\"sleep 5 && $cmd\"");
}

#======================================================================
# sctpStartOptionServer - start a sctp server with option at remote system
#======================================================================
sub sctpStartOptionServer(;$$) {
	my ($IF, $opts) = @_;
	my ($cmd);

	$IF = "Link0" if !defined($IF);

	vLogTitle('=========== sctpStartOptionServer ==========');

	$cmd  = "sctp_darn ";
	$cmd .= "-H $CONF{SCTP_NUT_NET0_ADDR} -P $CONF{SCTP_NUT0_PORT} -l ";
	$cmd .= $opts if defined($opts);
	$cmd .= " &";

	sctpRemoteCommandAsync($cmd);
}

#======================================================================
# sctpStartInteractiveServer - start a sctp interactive mode
#                              server at remote system
#======================================================================
sub sctpStartInteractiveServer(;$@) {
	my ($IF, @subcmds) = @_;
	my ($cmd, $script);

	$IF = "Link0" if !defined($IF);

	vLogTitle('========= sctpStartInteractiveServer =======');

	$cmd  = "sctp_darn ";
	$cmd .= "-H $CONF{SCTP_NUT_NET0_ADDR} -P $CONF{SCTP_NUT0_PORT} ";
	$cmd .= "-l -I ";
	$cmd .= "< /tmp/.sctp_icmds &";
	
	$script = "";
	foreach $subcmd (@subcmds) {
		if ($subcmd =~ /^add=(\S+)/) {
			$script .= "bindx-add=$1\n";
		} elsif ($subcmd =~ /^del=(\S+)/) {
			$script .= "bindx-rem=$1\n";
		} elsif ($subcmd =~ /^prim=(\S+)/) {
			$script .= "primary=$1\n";
		} elsif ($subcmd =~ /^pprim=(\S+)/) {
			$script .= "peer_primary=$1\n";
		} elsif ($subcmd =~ /^send=(\S+)/) {
			$script .= "snd=$1\n";
		} elsif ($subcmd =~ /^recv=(\S+)/) {
			$script .= "rcv=$1\n";
		} elsif ($subcmd =~ /^recv/) {
			$script .= "rcv\n";
		} elsif ($subcmd =~ /^shutdown/) {
			$script .= "shutdown\n";
		} elsif ($subcmd =~ /^abort/) {
			$script .= "abort\n";
		} elsif ($subcmd =~ /^heartbeat=(\S+)/) {
			$script .= "heartbeat=$1\n";
		} elsif ($subcmd =~ /^heartbeat/) {
			$script .= "heartbeat\n";
		} else {
			vLog("Unknown parameter $subcmd");
		}
	}

	open (FILE, ">.sctp_icmds") || die "Cannot open .sctp_icmds: $!\n";
	print FILE $script;
	close FILE;

	sctpPutFile(".sctp_icmds", "/tmp/.sctp_icmds");

	sctpRemoteCommandAsync($cmd);
}

#======================================================================
# sctpStatusServer - start a sctp server at remote system, output
#                    status to file /tmp/sctpstatus
#======================================================================
sub sctpStatusServer(;$$$) {
	my ($IF, $count, $opts) = @_;
	my ($cmd);
	my $file = "/tmp/sctpstatus";

	vLogTitle('============== sctpStatusServer ============');

	$IF = "Link0" if !defined($IF);
	$count = 1 if !defined($count);

	$cmd  = "sctp_status ";
	$cmd .= "-H $CONF{SCTP_NUT_NET0_ADDR} -P $CONF{SCTP_NUT0_PORT} -l ";
	$cmd .= $opts if defined($opts);
	$cmd .= "-X 1 " if (!($cmd =~ /-X\s+/));
	$cmd .= "-x $count " if (!($cmd =~ /-x\s+/));
	$cmd .= "-f $file &";

	sctpRemoteCommandAsync($cmd);
}

#======================================================================
# sctpStatusClient - start a sctp client at remote system, output
#                    status to file /tmp/sctpstatus
#======================================================================
sub sctpStatusClient(;$$$) {
	my ($IF, $count, $opts) = @_;
	my ($cmd);
	my $file = "/tmp/sctpstatus";

	vLogTitle('============= sctpStatusClient =============');

	$IF = "Link0" if !defined($IF);
	$count = 1 if !defined($count);

	$cmd  = "sctp_status ";
	$cmd .= "-H $CONF{SCTP_NUT_NET0_ADDR} -P $CONF{SCTP_NUT0_PORT} ";
	$cmd .= "-h $CONF{SCTP_TN_NET0_ADDR} -p $CONF{SCTP_TN0_PORT} -s ";
	$cmd .= " $opts " if defined($opts);
	$cmd .= "-X 1 " if (!($cmd =~ /-X\s+/));
	$cmd .= "-x $count " if (!($cmd =~ /-x\s+/));
	$cmd .= "-c " . $CONF{"DEFAULT_DATA_LEN"} . " " if (!($cmd =~ /-c\s+/));
	$cmd .= "-f $file &";

	sctpRemoteCommandAsyncDelay($cmd);
}

#======================================================================
# sctpMakeBadMD5Cookie - make a cookie with bad signature
#======================================================================
sub sctpMakeBadMD5Cookie($) {
	my ($cookie) = @_;
	my $len, $ret;

	$len = length($cookie);

	$ret = sprintf "%0".$len."d", 0;
}

#======================================================================
# sctpTimeFuzzyEqual - compare time is equal under fuzzy time
#======================================================================
sub sctpTimeFuzzyEqual($$$) {
	my ($cmptime, $basetime, $fuzzy) = @_;

	return ($cmptime >= ($basetime - $fuzzy) && $cmptime <= ($basetime + $fuzzy));
}

#======================================================================
# sctpGetFile - get a file from remote system
#======================================================================
sub sctpGetFile($$) {
	my ($from, $to) = @_;

	vRemote("getfile.rmt", "from=$from", "to=$to") && return 1;

	return 0;
}

#======================================================================
# sctpPutFile - put file to remote system
#======================================================================
sub sctpPutFile($$) {
	my ($from, $to) = @_;
	
	vRemote("putfile.rmt", "from=$from", "to=$to") && return 1;

	return 0;
}

#======================================================================
# sctpGetMIBValue - get MIB value from remote system
#======================================================================
sub sctpGetMIBValue($) {
	my ($name) = @_;
	my $value = 0;
	my $lfile = ".sctpsnmp";

	my %SCTP_MIB = (
		SCTP_MIB_CURRESTAB			=> "SctpCurrEstab", 
		SCTP_MIB_ACTIVEESTABS			=> "SctpActiveEstabs", 
		SCTP_MIB_PASSIVEESTABS			=> "SctpPassiveEstabs", 
		SCTP_MIB_ABORTEDS			=> "SctpAborteds", 
		SCTP_MIB_SHUTDOWNS			=> "SctpShutdowns", 
		SCTP_MIB_OUTOFBLUES			=> "SctpOutOfBlues", 
		SCTP_MIB_CHECKSUMERRORS			=> "SctpChecksumErrors", 
		SCTP_MIB_OUTCTRLCHUNKS			=> "SctpOutCtrlChunks", 
		SCTP_MIB_OUTORDERCHUNKS			=> "SctpOutOrderChunks", 
		SCTP_MIB_OUTUNORDERCHUNKS		=> "SctpOutUnorderChunks", 
		SCTP_MIB_INCTRLCHUNKS			=> "SctpInCtrlChunks", 
		SCTP_MIB_INORDERCHUNKS			=> "SctpInOrderChunks", 
		SCTP_MIB_INUNORDERCHUNKS		=> "SctpInUnorderChunks", 
		SCTP_MIB_FRAGUSRMSGS			=> "SctpFragUsrMsgs", 
		SCTP_MIB_REASMUSRMSGS			=> "SctpReasmUsrMsgs", 
		SCTP_MIB_OUTSCTPPACKS			=> "SctpOutSCTPPacks", 
		SCTP_MIB_INSCTPPACKS			=> "SctpInSCTPPacks", 
		SCTP_MIB_T1_INIT_EXPIREDS		=> "SctpT1InitExpireds", 
		SCTP_MIB_T1_COOKIE_EXPIREDS		=> "SctpT1CookieExpireds", 
		SCTP_MIB_T2_SHUTDOWN_EXPIREDS		=> "SctpT2ShutdownExpireds", 
		SCTP_MIB_T3_RTX_EXPIREDS		=> "SctpT3RtxExpireds", 
		SCTP_MIB_T4_RTO_EXPIREDS		=> "SctpT4RtoExpireds", 
		SCTP_MIB_T5_SHUTDOWN_GUARD_EXPIREDS	=> "SctpT5ShutdownGuardExpireds", 
		SCTP_MIB_DELAY_SACK_EXPIREDS		=> "SctpDelaySackExpireds", 
		SCTP_MIB_AUTOCLOSE_EXPIREDS		=> "SctpAutocloseExpireds", 
		SCTP_MIB_T3_RETRANSMITS			=> "SctpT3Retransmits", 
		SCTP_MIB_PMTUD_RETRANSMITS		=> "SctpPmtudRetransmits", 
		SCTP_MIB_FAST_RETRANSMITS		=> "SctpFastRetransmits", 
		SCTP_MIB_IN_PKT_SOFTIRQ			=> "SctpInPktSoftirq", 
		SCTP_MIB_IN_PKT_BACKLOG			=> "SctpInPktBacklog", 
		SCTP_MIB_IN_PKT_DISCARDS		=> "SctpInPktDiscards", 
		SCTP_MIB_IN_DATA_CHUNK_DISCARDS		=> "SctpInDataChunkDiscards", 
	);

	vLogTitle('============== sctpGetMIBValue =============');

	return -1 if ! defined $SCTP_MIB{$name};

	vRemote("getmibinfo.rmt", "name=$name", "to=$lfile") && return -1;

	$pattern = "^" . $SCTP_MIB{$name} . "\\s+(\\d+)";
	open(FILE, "$lfile") || return -1;

	#print file content for debug
	@lines = <FILE>;
	foreach $line (@lines) {
		vLogHTML("$line<BR>");
	}

	foreach $line (@lines) {
		if ($line =~ /$pattern/) {
			vLogHTML("== Get $name From Remote System is : $1 ==");
			return $1;
		} elsif (/No\s+such\s+file\s+or\s+directory/) {
			return -1;
		}
	}
	close(FILE);
	
	return -1;
}

#======================================================================
# sctpGetRemoteSys - get system config from remote system
#======================================================================
sub sctpGetRemoteSys($) {
	my ($name) = @_;
	my $value = 0;

	vLogTitle('============= sctpGetRemoteSys =============');

	my $lfile = lc($name);
	$lfile =~ s/\./_/g;

	vRemote("getsysconfig.rmt", "name=$name", "to=$lfile") && return 0;

	open (FILE, "$lfile") || die "Cannot open $!\n";
	while ( <FILE> ) {
		if( /^(\d+)/ ) {
			$value = $1;
		}
	}
	close FILE;
	unlink($lfile);
	
	vLogHTML("Paramater $name of Remote System is : $value");

	return $value;
}

#======================================================================
# sctpSetRemoteSys - set system config to remote system
#======================================================================
sub sctpSetRemoteSys($$) {
	my ($name, $value) = @_;

	vLogTitle('============= sctpSetRemoteSys =============');

	vRemote("setsysconfig.rmt", "name=$name", "value=$value") && return 0;

	vLogHTML("Set paramater $name of Remote System to value: $value");

	return 0;
}

#======================================================================
# sctpGetRemoteStatus - get status from remote system
#======================================================================
sub sctpGetRemoteStatus(@) {
	my (@limit) = @_;
	my $from = "/tmp/sctpstatus";
	my $to = ".sctpstatus";
	my @ret = ();
	my $limit, $cnt = 0;

	vLogTitle('============ sctpGetRemoteStatus ===========');

	sctpGetFile($from, $to) && return 0;

	open (FILE, "$to") || die "Cannot open $!\n";
	vLogHTML("<PRE>");
	while ( <FILE> ) {
		if(/^(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
			if(defined(@limit) && ($limit[$cnt] != $11 || $limit[$cnt] == '-')) {
				vLogHTML("<FONT COLOR=\"#FF0000\">$_</FONT>");
			} else {
				vLogHTML("$_");
			}
			$ret[$cnt] = $11;
			$cnt++;
		} else {
			vLogHTML("$_");
		}
		last if (defined(@limit) && $cnt >= @limit);
	}
	close FILE;
	vLogHTML("</PRE>");

	return @ret;
}

#======================================================================
# sctpPutAndCCFile - put C source file to NUT and compile it
#======================================================================
sub sctpPutAndCCFile($$$) {
	my ($from, $to, $cc) = @_;
	
	vRemote("putfile.rmt", "from=$from", "to=$to") && return 1;
	vRemote("rcommand.rmt", "cmd=\"$cc\"") && return 1;

	return 0;
}

#======================================================================
# sctpRemoteCommand - execute command on NUT
#======================================================================
sub sctpRemoteCommand($) {
	my ($cmd) = @_;

	vRemote("rcommand.rmt", "cmd=\"$cmd\"") && return 1;

	return 0;
}

#======================================================================
# sctpRemoteCommandAsync - asynchronous execute command on NUT
#======================================================================
sub sctpRemoteCommandAsync($) {
	my ($cmd) = @_;

	if (!($cmd =~ /</)) {
		if ($cmd =~ /&$/) {
			$cmd =~ s/&$//;
			$cmd .= " > /tmp/tstcmd.log 2>&1 &";
		} elsif (!($cmd =~ /<</ )) {
			$cmd .= " > /tmp/tstcmd.log 2>&1";
		}
	}

	vRemote("rcommandasync.rmt", "cmd=\"$cmd\"") && return 1;

	return 0;
}

#======================================================================
# sctpRemoteCommandAsyncDelay - asynchronous execute command on NUT
#======================================================================
sub sctpRemoteCommandAsyncDelay($;$) {
	my ($cmd, $dalay) = @_;

	$dalay = 5 if !defined($dalay);

	if ($cmd =~ /&$/ ) {
		$cmd =~ s/&$//;
		$cmd .= " > /tmp/tstcmd.log 2>&1 &";
	} elsif (!($cmd =~ /<</ )) {
		$cmd .= " > /tmp/tstcmd.log 2>&1";
	}

	vRemote("rcommandasync.rmt", "cmd=\"sleep $dalay && $cmd\"") && return 1;

	return 0;
}

#======================================================================
# sctpSystem - execute command on locale machine
#======================================================================
sub sctpSystem($) {
	my ($cmd) = @_;
	my $OLD_SIG = $SIG{CHLD};

	vLogHTML("exec $cmd");
	# We MUST change $SIG{CHLD} to IGNORE
	# Otherwise function system will not return.
	$SIG{CHLD} = IGNORE;
	system($cmd);
	# Restore $SIG{CHLD} for V6evalTool
	$SIG{CHLD} = $OLD_SIG;
	return 0;
}

#======================================================================
# sctpReboot() - reboot NUT
#======================================================================
sub sctpReboot() {
	vLogHTML("Target: Reboot");
	vRemote("reboot.rmt", "") && return 1;
	return 0;
}

1;
