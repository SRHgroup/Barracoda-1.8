#!/usr/bin/perl

# Andrea Marquard
# Apr 27, 2015
#

# Requires FASTA file to be perfectly formatted. the script doesn't check. Consider running fix-fasta-format.pl first

my $fasta = $ARGV[0];

open(IN, "<", $fasta) or die "Cannot open $fasta\n";

while (defined(my $header = <IN>) ) {
	print $header;
	my $seq = <IN>;
	chomp $seq;
	print RevComp($seq), "\n";
}

close IN;

sub RevComp {
   my($dna) = @_;
   $dna =~ tr/ATCGatcg/TAGCTAGC/;
   $dna = reverse $dna;
   return $dna;
}