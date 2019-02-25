#!/usr/bin/perl
use warnings;
use strict;
use autodie;

use Data::Dump qw(dump);

use IO::Socket::INET;
use Time::HiRes;

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


my $next_nop_t = time() + 5;

while(1) {
	our $client_socket = $socket->accept();

	sub client_send {
		my $text = join('', @_);
		warn ">> $text\n";
		print $client_socket "$text\r\n";
	}

	sub client_line {
		#my $line = <$client_socket>;

		my $line;
		my $timeout = $next_nop_t - time();
		if ( $timeout > 0 ) {
			eval {
				local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
				alarm $timeout;
				warn "# NOP alarm $timeout";
				$line = <$client_socket>;
				alarm 0;
			};
			if ($@) {
				# timed out
				client_send ".NOP";
				$line = <$client_socket>;
			}
		} else {
			$line = <$client_socket>;
		}

		if ( defined $line ) {
			$line =~ s/[\r\n]+$//;
			warn "<< $line\n";
		} else {
			warn "<< [NULL] connected: ",dump($client_socket), $client_socket->connected;
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

			client_send "2"; # nr of items in list
			#            status: 0/3
			#            | pages
			#            | | title
			#            | | |                   queue
			client_send "3|1|Koha online catalog|XWC7232";
			client_send "3|1|Koha online catalog|XWC5225";
			# FIXME

		} elsif ( $line =~ m/\.ACTION PRINT (ALL|\d+)/ ) {
			my $what = $1;
			my $job = $1 if $1 =~ m/^\d+$/; # 0 means print all?

			my $charge = $prices->{'A4'} || die "no A4 price";

			my $nr_jobs = 2;

			if ( $nr_jobs == 0 ) {
				client_send ".ACTION NOJOB Nema se šta tiskat";
				next;
			}

			# FIXME
			warn "FIXME $line\n";
			client_send ".ACTION PRINT"; # device locked from terminal screen?

			# check if printer ready
			my $printer_ready = 0;
			if ( ! $printer_ready ) {
				client_send ".WARN 1/1|The printer is not ready|job has been suspended ... (1x)";
				next;
			}

			my $send = 0; # 0 .. 100
			my $printed = 0; # 0 .. nr pages

			#                   total pages in batch
			#                   | page/batch
			#                   | |   title
			#                   | |   |
			client_send ".PRINT 1|1/1|Microsoft Word - molba_opca";
			client_send ".NOP S $send C 0";

			# open 10.60.3.25:9100
			$send = 100;

			client_send ".NOP S $send C 0";
			client_send ".MSG Please check display of device" if $send == 100;

			# check smtp counters to be sure page is printed

			$credit        -= $charge;
			$total_charged += $charge;
			$total_pages++;

			client_send ".DONE $nr_jobs $total_pages ".credit($total_charged);

		} elsif ( $line =~ m/^\.NOP/ ) {
			# XXX it's important to sleep, before sending response or
			# interface on terminal device will be unresponsive
			$next_nop_t = time() + 5; # NOP every 5s?
		} elsif ( $line =~ m/^\.END/ ) {
			client_send  ".DONE BLK WAIT";
			$client_socket->close;
		} elsif (defined $line) {
			warn "UNKNOWN: ",dump($line);
			print "Response>";
			my $r = <STDIN>;
			chomp $r;
			client_send $r;
		} else {
			warn "NULL line, connected ", $client_socket->connected;
		}
	}
	warn "# return to accept";
}

$socket->close();


