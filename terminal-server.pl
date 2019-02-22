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

print "$0 waiting for client connection on port 4096\n";

my $prices = {
	A3 => 0.3, # FIXME
	A4 => 0.2,
	BW => 0.0, # just paper cost
	COLOR => 3.99, # FIXME
	DUPLEX => -0.05,
};

while(1) {
	our $client_socket = $socket->accept();

	sub client_send {
		my $text = join('', @_);
		warn ">> $text\n";
		print $client_socket "$text\r\n";
	}

	sub client_line {
		my $line = <$client_socket>;
		if ( defined $line ) {
			$line =~ s/[\r\n]+$//;
			warn "<< $line\n";
		}
		return $line;
	}

	# get the host and port number of newly connected client.
	my $peer_address = $client_socket->peerhost();
	my $peer_port = $client_socket->peerport();

	print "Connection from: $peer_address:$peer_port\n";

	my $credit = 3.30;
	my $total_charged = 0.00;
	my $total_pages   = 0;
	sub credit {
		my $v = $credit;
		$v = $_[0] if defined $_[0];
		return sprintf "%1.2f kn", $v;
	}

	while ($client_socket->connected) {

		my $line = client_line;

		if ( $line =~ m/^\.SQ ([\d\.]+) (\S+)/ ) {
			my ($version,$serial) = ($1,$2);
			client_send  ".SQ OK";
			#client_send  ".SQ FAILED message";
		} elsif ( $line =~ m/^\.CFG/ ) {
			client_send  ".CFG OK %s";
		} elsif ( $line =~ m/\.SERVER LIST/ ) {
			client_send  ".ERROR NO-ENTERPRISE";
		} elsif ( $line =~ m/\.CARD (\S+)/ ) {
			my ($rfid_sid) = $1;
			client_send  ".CARD OK Ime Prezime (nobody\@example.com)";
		} elsif ( $line =~ m/\.PIN (\S+)/ ) {
			my ($pin) = $1;
			client_send  ".PIN OK Ime Pinzime (nobody\@example.com)";
		} elsif ( $line =~ m/\.ACTION$/ ) {
			# CMENUS0 - no printer
			client_send  ".ACTION CMENUS68"; # FIXME can be CMENUS2

		} elsif ( $line =~ m/\.ACTION COPY/ ) {
			client_send  ".ACTION COPY";	# safeq sends this twice
			client_send  ".COPY Mozete kopirati |".credit;
			client_send  ".NOP";
			client_send  ".CREDIT ".credit;
		} elsif ( $line =~ m/\.COPY (.+)/ ) {
			# FIXME
			my $charge = 0;
			foreach ( split(/,/,$1) ) {
				die "can't find [$_] in prices=",dump($prices) unless exists $prices->{$_};
				$charge += $prices->{$_};
			}
			warn "CHARGE: $charge\n";
			$credit        -= $charge;
			$total_charged += $charge;
			$total_pages++;
			client_send ".CREDIT ".credit;
			client_send ".COPY 1"; # I verified that you are allowed to copy 1 page?
			client_send ".NOP";

		} elsif ( $line =~ m/\.ACTION LIST/ ) {
			# FIXME

		} elsif ( $line =~ m/\.ACTION PRINT ALL/ ) {
			# FIXME

		} elsif ( $line =~ m/^\.NOP/ ) {
			# XXX it's important to sleep, before sending response or
			# interface on terminal device will be unresponsive
			sleep 1;
			client_send  ".NOP";
		} elsif ( $line =~ m/^\.END/ ) {
			client_send  ".DONE BLK WAIT";
			client_send  ".NOP";
			my $nop = client_line;
			client_send ".DONE $total_pages ".credit($total_charged);
			warn "expected NOP got: $nop" unless $nop =~ m/NOP/;
			my $null = client_line;
			$client_socket->close;
		} else {
			warn "UNKNOWN: ",dump($line);
			print "Response>";
			my $r = <STDIN>;
			chomp $r;
			client_send $r;
		}
	}
	warn "# return to accept";
}

$socket->close();


