#!/usr/bin/perl
use warnings;
use strict;

use Data::Dump qw(dump);

my $ip = shift @ARGV || '10.60.3.35';
my $debug = $ENV{DEBUG} || 0;
my $sep = $ENV{SEP} || "\t";

my $op = shift @ARGV || 'list';

my $url = 'jblist.htm';
if ( $op eq 'list' ) {
	$url = 'jblist.htm';
} elsif ( $op eq 'hist' ) {
	$url = 'jbhist.htm';
} else {
	die "UNKNOWN op [$op]\n";
}

warn "# $ip/$url" if $debug;
open(my $curl, '-|', "curl --silent http://$ip/$url");
my $info;
while(<$curl>) {
	if ( m/var (stats|types|info|hdrs|stsAry|jHst)=(.*);/ ) {
		my $json = $2;
		my $v = eval $json; # this is not valid JSON, but perl's eval doesn't mind
		#warn "# JSON $json -> ",dump($v);
		$info->{$1} = $v;
	}
}

warn "# info=",dump($info) if $debug;

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
