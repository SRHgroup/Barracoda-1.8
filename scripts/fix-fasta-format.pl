#!/usr/bin/perl

# Andrea Marquard
# Apr 27, 2015
#

my $fasta = $ARGV[0];

open(IN, "<", $fasta) or die "Cannot open $fasta\n";

while (defined(my $header = <IN>) ) {
	while ($header =~ m/^>/) {
		if (defined(my $seq = <IN>) ) {
			if ($seq =~ m/^([ACTG]+)\s?$/) {
				print $header;
				print $seq;
				$header = '';
			} else {
				$header = $seq;
			}
		} else {
			# file ended;
		}
	}
}

close IN;