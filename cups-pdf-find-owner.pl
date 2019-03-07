#!/usr/bin/perl
use warnings;
use strict;
use autodie;

use Data::Dump qw(dump);
use File::Slurp;
use DBI;
use IO::Socket::INET;

my $socket = IO::Socket::INET->new(
	LocalPort => 4001,
	LocalAddr => 'localhost',
	Proto => 'tcp',
	Listen => 5,
	Reuse => 1
) or die "ERROR: $!";

open(my $log, '>>', '/var/log/cups/find_owner_log');
$SIG{__WARN__} = sub {
	print STDERR @_;
	print $log time(), " ", @_;
};

warn "$0 waiting for client connection on port ", $socket->sockaddr, ":", $socket->sockport, "\n";

while(1) {
	our $client_socket = $socket->accept();
	my $line = <$client_socket>;

	warn "<< [$line]";

#my ($file, $local_user, $remote_user) = @ARGV;
my ($file, $local_user, $remote_user) = split(/\s/,$line,3);

my $job_id = $1 if ( $file =~ m/job_(\d+)/ );

die "can't find job_id in [$file]" unless $job_id;

my $c_file = sprintf "/var/spool/cups/c%05d", $job_id;

if ( ! -e $c_file ) {
	my $wait = 5; # max s wait for file to appear
	while ( $wait ) {
		$0 = "find-owner #$job_id wait $wait s for $c_file";
		sleep 1;
		$wait--;
		last if -e $c_file;
	}
}

my $blob = read_file $c_file;

my (undef,$ip) = split(/job-originating-host-name\x00/, $blob, 2);
my $len = ord(substr($ip,0,1));
$ip = substr($ip,1,$len);

my $database = 'pGinaDB';
my $hostname = '10.60.4.9';
my $port     = 3306;
my $user     = 'pGina';
my $password = 'secret';

my $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";
my $dbh = DBI->connect($dsn, $user, $password);

my $sth = $dbh->prepare(qq{
	select * from pGinaSession where ipaddress = ? and logoutstamp is null order by loginstamp desc
}) or die "prepare statement failed: $dbh->errstr()";
$sth->execute($ip) or die "execution failed: $dbh->errstr()";
if ( $sth->rows < 1 ) {
	die "can't find IP for job $job_id";
} elsif ( $sth->rows > 1 ) {
	warn "ERROR: found $sth->rows() rows for $job_id, usng first one\n";
}
my $row = $sth->fetchrow_hashref();
warn "## row = ",dump($row);

$sth->finish;

my $username = $row->{username} || die "no username in row = ",dump($row);
$username =~ s/\@ffzg.hr$//; # strip domain, same as pGina

my $spool = '/var/spool/cups-pdf/';
mkdir "$spool/$username" if ( ! -e "$spool/$username" );
my $filename_only = $file;
$filename_only =~ s/^.*\///; # basename

my $to = "$spool/$username/$filename_only";
rename $file, $to;
warn "# $to";
$0 = "find-owner #$job_id $username $filename_only"

} # while(1)

