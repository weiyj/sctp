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
##############################################################################

$version = $ARGV[0];
$version = "ipv4" if !defined($version);
$version = lc($version);
$version = "ipv4" if ($version ne "ipv4" && $version ne "ipv6");

if (-r "../etc/nut.def") {
	$file = "../etc/nut.def";
} elsif (-r "etc/nut.def") {
	$file = "etc/nut.def";
} elsif (-r "../nut.def") {
	$file = "../nut.def";
} else {
	$file = "nut.def";
}

$value = "";
$nochg = 0;
open (CONFIG, $file) || die "Cannot open $!\n";

while (<CONFIG>) {
	if (/^(Type)\s+(.*)/) {
		if ($2 eq $version) {
			$nochg = 1;
			last;
		}
		if ($version eq "ipv4") {
			$_ =~ s/$2/IPv4/;
		} else {
			$_ =~ s/$2/IPv6/;
		}
	}
	$value .= $_;
}

close (CONFIG);

if ($nochg == 0) {
	open (CONFIG, ">$file") || die "Cannot open $!\n";
	print CONFIG $value;
	close (CONFIG);
}

if(-r "../common/sctpconf.def") {
	$file = "../common/sctpconf.def";
} else {
	$file = "common/sctpconf.def";
}
$value = "";
$nochg = 0;
open (CONFIG, $file) || die "Cannot open $!\n";

while (<CONFIG>) {
	if (/^#define\s+(ENABLE_IPV6)\s+(\S+)/) {
		if ($2 eq $version) {
			$nochg = 1;
			last;
		}
		if ($version eq "ipv4") {
			$_ =~ s/$2/0/;
		} else {
			$_ =~ s/$2/1/;
		}
	}
	$value .= $_;
}

close (CONFIG);

if ($nochg == 0) {
	open (CONFIG, ">$file") || die "Cannot open $!\n";
	print CONFIG $value;
	close (CONFIG);
}
