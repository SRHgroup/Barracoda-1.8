#!/usr/bin/perl -w


# Andrea Marquard
# May 5, 2015
#

# Requires FASTQ file to be perfectly formatted. the script doesn't check.
use strict;

my $fastq = $ARGV[0];
my %LEN = ();

open(IN, "<", $fastq) or die "Cannot open $fastq\n";
while (defined(my $header = <IN>) ) {
	my $seq = <IN>;
	chomp $seq;
	my $l = length($seq);
	if (exists($LEN{$l})) {
		$LEN{$l}++;
	} else {
		$LEN{$l} = 1;
	}
    <IN>;     # + line
    <IN>;     # quality line
}
close IN;

print "length\treads\n";
foreach my $l (sort  { $a <=> $b } keys %LEN) {
	print "$l\t$LEN{$l}\n";
}


