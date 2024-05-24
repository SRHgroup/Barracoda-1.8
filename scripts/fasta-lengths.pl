#!/usr/bin/perl

# Andrea Marquard
# Apr 27, 2015
#

# Requires FASTA file to be perfectly formatted. the script doesn't check. Consider running fix-fasta-format.pl first
use strict;

my $fasta = $ARGV[0];
my %LEN = ();
# my $n = 0;

open(IN, "<", $fasta) or die "Cannot open $fasta\n";
while (defined(my $header = <IN>) ) {
	# $n++;
	# print $header;
	my $seq = <IN>;
	chomp $seq;
	my $l = length($seq);
	if (exists($LEN{$l})) {
		$LEN{$l}++;
	} else {
		$LEN{$l} = 1;
	}
}
close IN;

print "length\treads\n";
foreach my $l (sort { $a <=> $b } keys %LEN) {
	print "$l\t$LEN{$l}\n";
}

# my @lengths = sort keys %LEN;
# print "Length distribution in fasta file:\n";
# for (my $l = $lengths[0]; $l <= $lengths[-1]; $l++) {
# 	if (exists($LEN{$l})) {
# 		my $num = 100 * $LEN{$l} / $n;
# 		print "$l\t$num %\n";
# 	} else {
# 		next;
# 		# print "$l\t0 %\n";
# 	}
# }


