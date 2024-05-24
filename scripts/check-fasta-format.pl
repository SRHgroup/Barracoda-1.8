#!/usr/bin/perl

# Andrea Marquard
# Apr 27, 2015
#

my $fasta = $ARGV[0];

open(IN, "<", $fasta) or die "Cannot open $fasta\n";
my $line;
# HEADER:
while (defined($line = <IN>) && $line =~ m/^>/) {
	print $line;
	# SEQUENCE:
	if (defined($line = <IN>) && $line =~ m/^([ACTG]+)\s?$/) {
		print $line;
	} else {
		die "Corrupt format of FASTA entry, at line $..\n" if defined $line;
		die "File ended before end of FASTA entry, at line $..\n";
	}
}
die "Corrupt format of FASTA entry, at line $..\n" if defined $line;

close IN;