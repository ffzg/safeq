#!/usr/bin/perl
use warnings;
use strict;

use Data::Dump qw(dump);

my $ip = shift @ARGV || '10.60.3.35';
my $debug = $ENV{DEBUG} || 0;

open(my $curl, '-|', "curl --silent http://$ip/jblist.htm");
my $info;
while(<$curl>) {
	if ( m/var (stats|types|info|hdrs)=(.*);/ ) {
		my $json = $2;
		my $v = eval $json; # this is not valid JSON, but perl's eval doesn't mind
		#warn "# JSON $json -> ",dump($v);
		$info->{$1} = $v;
	}
}

warn "# info=",dump($info) if $debug;

my $fmt = "%-8s|%-16s|%-16s|%-16s|%-16s|%s\n"; # last should be %d, but this doesn't work for header
printf $fmt, 'id', @{ $info->{hdrs} };

foreach my $l ( @{ $info->{info} } ) {
	warn "## l=",dump($l) if $debug > 1;
	
	printf $fmt,
		$l->[0], $l->[1], $l->[2], $info->{stats}->[ $l->[3] ], $info->{types}->[ $l->[4] ], $l->[5];
}
