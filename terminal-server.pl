#!/usr/bin/perl
use warnings;
use strict;

use Data::Dump qw(dump);

use IO::Socket::INET;

$| = 1;

my $socket = IO::Socket::INET->new(
	LocalPort => 4096,
	Proto => 'tcp',
	Listen => 5,
	Reuse => 1
) or die "ERROR: $!";

print "SERVER Waiting for client connection on port 4096\n";

while(1) {
	my $client_socket = $socket->accept();

	sub client_send {
		my $text = join('', @_);
		warn ">> $text\n";
		print $client_socket "$text\r\n";
	}

	# get the host and port number of newly connected client.
	my $peer_address = $client_socket->peerhost();
	my $peer_port = $client_socket->peerport();

	print "Connection from: $peer_address:$peer_port\n";

	while ($client_socket->connected) {
		my $line = <$client_socket>;
		$line =~ s/[\r\n]+$//;

		warn "<< $line\n";

		if ( $line =~ m/^\.SQ ([\d\.]+) (\S+)/ ) {
			client_send  ".SQ OK";
		} elsif ( $line =~ m/^\.CFG/ ) {
			client_send  ".CFG OK %s";
		} elsif ( $line =~ m/\.SERVER LIST/ ) {
			client_send  ".ERROR NO-ENTERPRISE";
		} elsif ( $line =~ m/\.CARD (\S+)/ ) {
			client_send  ".CARD OK Ime Prezime (nobody\@example.com)";
		} elsif ( $line =~ m/\.ACTION$/ ) {
			client_send  ".ACTION CMENUS0"; # FIXME can be CMENUS2
		} elsif ( $line =~ m/\.ACTION COPY/ ) {
			client_send  ".ACTION COPY";
			client_send  ".COPY Mozete kopirati (pero)";
		} elsif ( $line =~ m/(\.NOP)/ ) {
			client_send  "$1";
		} else {
			die "UNKNOWN: ",dump($line);
		}
	}
}

$socket->close();
