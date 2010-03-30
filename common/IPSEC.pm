#!/usr/bin/perl
#
# SCTP Conformance Test Suite Implementation
# (C) Copyright Fujitsu Ltd. 2008, 2009, 2010
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
package IPSEC;

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
	ipsecSetSAD
	ipsecSetInSAD
	ipsecSetOutSAD
	ipsecSetSPD
	ipsecSetDiscardSPD
	ipsecSetInSPD
	ipsecSetOutSPD
	ipsecClearAll
);

use V6evalTool;
use SCTP;

#======================================================================
# BEGIN -
#======================================================================
#BEGIN {
#}

#======================================================================
# END - clear all SAD and SPD entries
#======================================================================
END {
	# remember exit status, this maybe change after following process
	my $oldret = $?;

	$ret = vRemote("ipsecClearAll.rmt");
	if ($ret) {
		vLogHTML("Cannot Clear all SAD and SPD entries<BR>");
		if ($ret == $V6evalTool::exitNS) {
			vLogHTML("This test is not supported now<BR>");
			exit $V6evalTool::exitNS;
		} else {
			vLogHTML('<FONT COLOR="#FF0000">NG</FONT><BR>');
			exit $V6evalTool::exitFail;
		}
	}

	# exit with the last exit status
	exit($oldret);
}

#======================================================================
# ipsecSetSAD() - set SAD entries
#======================================================================
sub ipsecSetSAD(@) {
	vLogHTML("Target: Set SAD entries: @_");
	$ret = vRemote("ipsecSetSAD.rmt", "@_", $remote_debug);
	if ($ret) {
		vLogHTML("Cannot Set SAD entries: @_ <BR>");
		if ($ret == $V6evalTool::exitNS) {
			vLogHTML("This test is not supported now<BR>");
			exit $V6evalTool::exitNS;
		} else {
			vLogHTML('<FONT COLOR="#FF0000">NG</FONT><BR>');
			exit $V6evalTool::exitFail;
		}
	}
}

#======================================================================
# ipsecSetInSAD() - warp of set Inbound SAD entries
#======================================================================
sub ipsecSetInSAD(@) {
	ipsecSetSAD("src=$SCTP::CONF{'SCTP_TN_NET0_ADDR'}",
		    "dst=$SCTP::CONF{'SCTP_NUT_NET0_ADDR'}",
		    "mode=transport", @_);
}
	
#======================================================================
# ipsecSetOutSAD() - warp of set Outbound SAD entries
#======================================================================
sub ipsecSetOutSAD(@) {
	ipsecSetSAD("src=$SCTP::CONF{'SCTP_NUT_NET0_ADDR'}",
		    "dst=$SCTP::CONF{'SCTP_TN_NET0_ADDR'}",
		    "mode=transport", @_);
}

#======================================================================
# ipsecSetSPD() - set SPD entries
#======================================================================
sub ipsecSetSPD(@) {
	vLogHTML("Target: Set SPD entries: @_");
	$ret = vRemote("ipsecSetSPD.rmt", "@_", $remote_debug);
	if ($ret) {
		vLogHTML("Cannot Set SPD entries: @_ <BR>");
		if ($ret == $V6evalTool::exitNS) {
			vLogHTML("This test is not supported now<BR>");
			exit $V6evalTool::exitNS;
		} else {
			vLogHTML('<FONT COLOR="#FF0000">NG</FONT><BR>');
			exit $V6evalTool::exitFail;
		}
	}
}

#======================================================================
# ipsecSetDiscardSPD() - warp of set Disacrd SPD entries
#======================================================================
sub ipsecSetDiscardSPD(@) {
	my ($dir, $item);

	foreach $item (@_) {
		$dir = $1 if ($item =~ /^direction=(\S+)/); 
	}

	if ($dir eq "out") {
		ipsecSetSPD("src=$SCTP::CONF{'SCTP_NUT_NET0_ADDR'}",
			    "dst=$SCTP::CONF{'SCTP_TN_NET0_ADDR'}",
			    "policy=discard", "upperspec=sctp", @_);
	} else {
		ipsecSetSPD("src=$SCTP::CONF{'SCTP_TN_NET0_ADDR'}",
			    "dst=$SCTP::CONF{'SCTP_NUT_NET0_ADDR'}",
			    "policy=discard", "upperspec=sctp", @_);
	}
}

#======================================================================
# ipsecSetInSPD() - warp of set Inbound SPD entries
#======================================================================
sub ipsecSetInSPD(@) {
	ipsecSetSPD("src=$SCTP::CONF{'SCTP_TN_NET0_ADDR'}",
		    "dst=$SCTP::CONF{'SCTP_NUT_NET0_ADDR'}",
		    "upperspec=sctp", "direction=in", "mode=transport", @_);
}

#======================================================================
# ipsecSetOutSPD() - warp of set Outbound SPD entries
#======================================================================
sub ipsecSetOutSPD(@) {
	ipsecSetSPD("src=$SCTP::CONF{'SCTP_NUT_NET0_ADDR'}",
		    "dst=$SCTP::CONF{'SCTP_TN_NET0_ADDR'}",
		    "upperspec=sctp", "direction=out", "mode=transport", @_);
}

#======================================================================
# ipsecClearAll() - clear all SAD and SPD entries
#======================================================================
sub ipsecClearAll() {
	vLogHTML("Target: Clear all SAD and SPD entries");
	$ret = vRemote("ipsecClearAll.rmt", $remote_debug);
	if ($ret) {
		vLogHTML("Cannot Clear all SAD and SPD entries<BR>");
		if ($ret == $V6evalTool::exitNS) {
			vLogHTML("This test is not supported now<BR>");
			exit $V6evalTool::exitNS;
		} else {
			vLogHTML('<FONT COLOR="#FF0000">NG</FONT><BR>');
			exit $V6evalTool::exitFail;
		}
	}
}

1;
