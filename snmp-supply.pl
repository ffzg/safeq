#!/usr/bin/perl
use warnings;
use strict;
use autodie;
use Data::Dump qw(dump);

my $ip = shift @ARGV || '10.60.3.35';
my $sep = $ENV{SEP} || "\t";

my $stat = { _take => 1 };

my $cache = "/dev/shm/$ip.snmp";
my $snmp;
if ( -e $cache ) {
	open($snmp, '<', $cache);
	warn "# cache $cache";
} else {
	my $cmd = "snmpwalk -v1 -cpublic $ip | tee /dev/shm/$ip.snmp";
	warn "# $cmd";
	open($snmp, '-|', $cmd);
}

while(<$snmp>) {
	chomp;

	if ( m/Supplies/ ) {
		$stat->{_take} = 1;
	} else {
		$stat->{_take} = 0;
	}

	if ( $stat->{_take} && m/::([^\.]+)\.(.+) = (\w+): (.+)/ ) {
		my ($name,$id,$type,$val) = ( $1,$2,$3,$4 );
		$stat->{$id}->{$name} = $val;
		$stat->{_ids}->{$id}++;

		if ( $stat->{_order}->[-1] ne $name ) {
			push @{ $stat->{_order} }, $name;
		}
	}

}

warn "# stat = ",dump($stat);

my @order = @{ $stat->{_order} };
warn "# order = ",dump( \@order );

my @ids = keys %{ $stat->{_ids} };

warn "# ids = ",dump( \@ids );

print join($sep,'IP', 'ID', @order),"\n";
foreach my $id ( @ids ) {
	print join($sep, $ip, $id, map { $stat->{$id}->{$_} } @order),"\n";
}

