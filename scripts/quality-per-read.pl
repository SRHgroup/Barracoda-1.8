#!/usr/bin/perl -w

use strict;

# # Get quality read from STDIN
# my $qual = <STDIN>;
# chomp $qual;

# # Get FASTQ file
my $fasta;
my $base = 33;
my $id = '';
my @four_lines;

if (scalar @ARGV == 1) {
	($fasta) = @ARGV;
} else {
	die "Give name of one FASTQ file\n";
}

open(IN, '<', $fasta) or die "Cannot open $fasta\n";
while(defined(my $line = <IN>)) {
	chomp $line;
	if ($line =~ m/^@/) { # header line
        <IN>;             # sequence line
        <IN>;             # + line
        my $q = <IN>;     # quality line
        chomp $q;
        my ($mean, $length) = &MeanQuality($q);
		print "$line\t$length\t$mean\n"; # quality
	} else {
		die "Corrupted format.\n";
	}
}
close IN;


# print "Sequence quality score = ", &MeanQuality($qual), "\n";

sub MeanQuality {
	(my $qread) = @_;
	my $n = 0;
	my $sum = 0;
	for (my $i = 0; $i < length $qread; $i++) {
		my $char = substr($qread, $i, 1);
		my $quality = ord($char)-$base;
		$sum += $quality;
		$n++;
	}
	my $mean_qual = $sum/$n;
    return($mean_qual, $n)
}

# # See each character and its associated quality score
# for (my $i = 0; $i < length $qual; $i++) {
# 	my $q = substr($qual, $i, 1);
# 	print $q, " ", ord($q)-$base, "\n";
# }


# # Test that my alphabet works
# my $alphabet = "!\"#\$\%&'()*+,-./0123456789:;<=>?\@ABCDEFGHIJ";
# my $base = ord(substr($alphabet, 0, 1)); # my "zero" base value
# for (my $i = 0; $i < length $alphabet; $i++) {
# 	my $num = substr($alphabet, $i, 1);
# 	print $num, "\t", ord($num), "\t", ord($num)-$base, "\n";
# }