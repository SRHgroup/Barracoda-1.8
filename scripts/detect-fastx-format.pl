#!/usr/bin/perl

# Andrea Marquard
# Apr 27, 2015
#

my $file = $ARGV[0];
my $format = '';

open(IN, "<", $file) or die "Cannot open $file\n";
if (defined(my $header = <IN>) ) {
	if ($header =~ m/^>/) {
		$format = "fasta";
	} elsif ($header =~ m/^@/) {
		$format = "fastq";
	} 
} else {
	die "File is empty\n";
}
close IN;

print $format;