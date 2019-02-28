#!/usr/bin/perl
use warnings;
use strict;

use Data::Dump qw(dump);

my $ip = shift @ARGV || '10.60.3.35';
my $debug = $ENV{DEBUG} || 0;
my $sep = $ENV{SEP} || "\t";

my $op = shift @ARGV || 'list';

my $url;
my $var_re;

if ( $op =~ m/^l/i ) { # list
	$url = 'jblist.htm';
	$var_re = '(stats|types|info|hdrs)';
} elsif ( $op =~ m/^h/i ) { # history
	$url = 'jbhist.htm';
	$var_re = '(hdrs|stsAry|types|jHst)';
} elsif ( $op =~ m/^s/i ) { # status
	$url = 'stgen.htm';
	$var_re = '(lbls|spcs|adrslbl)';
} elsif ( $op =~ m/^t/i ) { # tray
	$url = 'sttray.htm';
	$var_re = '(hdrIn|infoIn|hdrOut|infoOut|stsIn)';
} elsif ( $op =~ m/^e/i ) { # error
	$url = 'sperr.htm';
	$var_re = '(lHdr|errLog)';
} elsif ( $op =~ m/^(d|c)/i ) { # delete/cancel
	my $job_id = join('/', @ARGV) || die "expected job_id(s) missing";
	open(my $curl, '-|', "curl --silent -XPOST -d OPR=CANCEL -d JOBS=$job_id/ http://$ip/JOBCTRL.cmd");
	while (<$curl>) {
		if ( m/<title>/i ) {
			chomp;
			s/<[^>]*>//g;
			print join($sep, $ip, $job_id, 'CANCEL', $_),"\n";
		}
	}
	exit 0;
} else {
	die "UNKNOWN op [$op]\n";
}

warn "# $ip/$url" if $debug;
open(my $curl, '-|', "curl --silent http://$ip/$url");
my $info;
while(<$curl>) {
	if ( m/var ${var_re}=(.*);/ ) {
		my $name = $1;
		my $json = $2;
		my $v = eval $json; # this is not valid JSON, but perl's eval doesn't mind
		warn "## JSON $name $json -> ",dump($v) if $debug > 1;
		$info->{$1} = $v;
	}
}

warn "# info=",dump($info) if $debug;

if ( exists $info->{spcs} ) {
	print join($sep, @{ $info->{lbls} }),"\n";

	my @s = @{ $info->{spcs} };
	foreach my $i ( 0 .. $#{ $s[1] } ) {
		$s[1]->[$i] .= ' ' . $info->{adrslbl}->[$i];
	}
	$s[1] = join(',', @{ $s[1] });
	
	print join($sep, @s),"\n";

	exit 0;

} elsif ( exists $info->{errLog} ) {
	print join($sep, 'IP', @{ $info->{lHdr} }),"\n";
	foreach my $error ( @{ $info->{errLog} } ) {
		print join($sep, $ip, @{ $error }),"\n";
	}
	exit 0;

} elsif ( exists $info->{infoIn} ) {
	print join($sep, 'IP', @{ $info->{hdrIn} }),"\n";
	foreach my $row ( @{ $info->{infoIn} } ) {
		$row->[1] .= ':' . $info->{stsIn}->[$row->[1]];
		print join($sep, $ip, @$row),"\n";
	}

	print join($sep, 'IP', @{ $info->{hdrOut} }),"\n";
	foreach my $row ( @{ $info->{infoOut} } ) {
		$row->[1] .= ':' . $info->{stsIn}->[$row->[1]];
		print join($sep, $ip, @$row),"\n";
	}
	exit 0;
} 

exit 1 if ! defined $info->{hdrs}; # we didn't get expected output

my @headers = @{ $info->{hdrs} };
unshift @headers, 'id' if $op eq 'list';
unshift @headers, 'IP';

print join($sep, @headers),"\n";

foreach my $l ( @{ $info->{info} } ) {
	warn "## l=",dump($l) if $debug > 1;
	
	$l->[3] .= ':' . $info->{stats}->[ $l->[3] ];
	$l->[4] .= ':' . $info->{types}->[ $l->[4] ];

	print join($sep, $ip, @$l), "\n";
}

foreach my $l ( @{ $info->{jHst} } ) {
	warn "## l=",dump($l) if $debug > 1;
	
	$l->[2] .= ':' . $info->{stsAry}->[ $l->[2] ];
	$l->[3] .= ':' . $info->{types}->[ $l->[3] ];

	print join($sep, $ip, @$l),"\n";
}
