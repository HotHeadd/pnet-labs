#!/usr/bin/perl
# Forward actual Kerio log records from Management. No detection is generated.
use strict;
use warnings;
use IO::Socket::INET;
use POSIX qw(strftime);
$| = 1;
my @logs = qw(connection security filter error alert);
my $socket = IO::Socket::INET->new(
    PeerAddr => '10.1.99.10', PeerPort => 514, Proto => 'udp',
    LocalAddr => '10.1.99.1',
) or die "syslog socket: $!";
my $pid = open(my $tail, '-|', '/usr/bin/tail', '-n', '0', '-F',
    map { "/var/winroute/logs/$_.log" } @logs) or die "tail: $!";
$SIG{TERM} = sub { kill 'TERM', $pid; exit 0; };
my $app = 'kerio-log';
while (my $line = <$tail>) {
    chomp $line;
    if ($line =~ m{^==> /var/winroute/logs/(\w+)\.log <==$}) {
        $app = "kerio-$1";
        next;
    }
    next unless length $line;
    # Never feed the transport's own records back into the same transport.
    next if $line =~ /\[Rule\] BKS4-Syslog|10\.1\.99\.10\)?:514/;
    my $time = strftime('%Y-%m-%dT%H:%M:%SZ', gmtime);
    $socket->send("<134>1 $time control $app - - - $line");
}
