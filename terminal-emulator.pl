#!/usr/bin/perl
use warnings;
use strict;

use Data::Dump qw(dump);

use IO::Socket::INET;

my $ip   = shift @ARGV || '127.0.0.1';
my $port = shift @ARGV || 4096;

my $socket = IO::Socket::INET->new(
	PeerAddr => $ip,
	PeerPort => $port,
	Proto => 'tcp',
) or die "ERROR $ip:$port - $!";

warn "# connected to $ip:$port\n";

my @send_receive = grep { /^.+$/ } split(/\n/, q{
.SQ 3.2.9 SQPR8463332F62E
.SQ OK

.CFG gd lang=HR
.CFG OK %s

.SERVER LIST
.ERROR NO-ENTERPRISE

.CARD E009000000009999
.CARD OK Ime Prezime (nobody@example.com)

.ACTION
.ACTION CMENUS0

.NOP
.NOP 


.NOP
.NOP 

.NOP
.NOP 

.NOP
.NOP 

.NOP
.NOP

.END 
});

#warn "# send_receive=",dump( \@send_receive );

while ( @send_receive ) {
	my $send   = shift @send_receive;
	my $expect = shift @send_receive;
	warn ">> $send\n";
	print $socket "$send\r\n";
	my $got = <$socket>;
	$got =~ s/[\r\n]+$//;
warn dump($send,$expect,$got);
	warn "<< $got\n";
	die "ERROR expected [$expect] got [$got]" if $expect ne $got;
}

$socket->close();
