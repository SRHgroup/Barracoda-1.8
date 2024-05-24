#!/usr/bin/perl

# Andrea Marquard
# Apr 27, 2015
#

my $fastq = $ARGV[0];

open(IN, "<", $fastq) or die "Cannot open $fastq\n";
my $line;
# HEADER:
while (defined($line = <IN>) && $line =~ m/^@/) {
	print $line;
	# SEQUENCE:
	if (defined($line = <IN>) && $line =~ m/^([ACTG]+)\s$/) {
		print $line;
	} else {
		die "Corrupt format of FASTQ entry, at line $..\n" if defined $line;
		die "File ended before end of FASTQ entry, at line $..\n";
	}
	# PLUS LINE:
	if (defined($line = <IN>) && $line =~ m/^\+\s$/) {
		print $line;
	} else {
		die "Corrupt format of FASTQ entry, at line $..\n" if defined $line;
		die "File ended before end of FASTQ entry, at line $..\n";
	}
	# QUALITY LINE:
	if (defined($line = <IN>)) {
		print $line;
	} else {
		die "File ended before end of FASTQ entry, at line $..\n";
	}
}
die "Corrupt format of FASTQ entry, at line $..\n" if defined $line;

close IN;