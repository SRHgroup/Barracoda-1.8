#!/usr/bin/perl -w

#$ENV{'PATH'} .= ':/tools/opt/bowtie2-2.3.4.1:/tools/opt/R-3.4.3/bin';   

use Cwd 'abs_path';
use File::Basename;

my $barracoda_path = '/tools/src/barracoda-1.8';

# Environment variable to root package dir
my $version = '1.8';   # don't change this variable to 1.1 untill you get a new directory on Athena with this suffix

# Not in www mode
# Temporary files are in /dev/shm/barracoda_$$ if on tuba, otherwise ./barracoda_$$/tmp
# Results (pdf and txt file, if chosen) are placed in current working dir/barracoda_$$
# Temporary files are deleted (unless -k is set), after storing some of them in /home/tuba/marquard/mhc_barcodes/archive/barracoda_$$

## Current directory
my $workingDir = `pwd`;
chomp $workingDir;

# In www mode (-w option)
# Temporary files are in /dev/shm/barracoda_$$ if on tuba, otherwise ./tmp/barracoda_$$
# Results (pdf and txt file, always generated) are placed in $wwwTempRootDir/$wwwTempDir/
# Temporary files are deleted (unless -k is set), after storing some of them in /home/tuba/marquard/mhc_barcodes/archive/barracoda_$$

my $wwwTempRootDir = "/var/www/html";
my $wwwTempDir = "services/Barracoda-"."$version"."/tmp/$$";

# Made by Andrea Marquard (Mar 20, 2015)
# Maintained by Kamilla K. Munk  

print "In case of problems, please email kamkj (at) dtu.dk, and provide the process id of your job: $$\n\n";    # DEBUGGING PURPOSES ONLY!!!

###############################################################################
###                                                                         ###
###   AIM:                                                                  ###
###                                                                         ###
###   Take a FASTQ file...                                                  ###
###   ...and some FASTA files with the expected primers and barcodes etc    ###
###   Map out the barcodes within the reads.                                ###
###                                                                         ###
###############################################################################



###############################################################################
#                                INITIAL CHECKS                               #
###############################################################################
# import the libraries
use strict;
use Getopt::Std;



#######################
#   CHECK FOR TOOLS   #
#######################
my $machine = `uname -n`;
chomp $machine;

my ($R, $bowtie2, $bowtie2Build);

if ($machine eq "tuba") {
  $R = "/home/tuba-nobackup/shared/R/R-3.2.0/bin/R";
  $bowtie2 = "/home/tuba-nobackup/shared/bin/bowtie2-align";
  $bowtie2Build = "/home/tuba-nobackup/shared/bin/bowtie2-build";
} else {
  $R = `which R`;
  chomp $R;
  $bowtie2 = `which bowtie2`;
  chomp $bowtie2;
  $bowtie2Build = `which bowtie2-build`;
  chomp $bowtie2Build;
}

my $perl     = "/usr/bin/perl";
my $split    = "/usr/bin/split";

die ("# perl cannot be found: $perl")          if (! -e $perl);
die ("# R cannot be found: $R.")               if (! -e $R);
die ("# bowtie2 could not be found: $bowtie2") if (! -e $bowtie2);
die ("# split could not be found: $split")     if (! -e $split);

print "$R ",$R,"\n"; 

my $parallel = "/usr/bin/parallel";
my $awk      = "/usr/bin/awk";
if (-e $parallel) {  # only need awk if we have parallel available
  die ("# The following tool could not be found: $awk")    if (! -e $awk);
}



#######################
#    COMMAND-LINE     #
#######################
my $command="$0 ";
my $i=0;

while (defined($ARGV[$i])){
  $command .= "$ARGV[$i] ";
  $i++;
}




#######################
#  INITIALISE PARAMS  #
#######################

my $verbose = 0;   # Verbose mode
my $wwwmode = 0;   # www-mode
my $cleanup = 1;   # Remove temp dir after execution of main program
*LOG=*STDERR;      # Logfile

my %Opt = ();      # Options
getopts('f:t:m:A:B:C:D:E:F:G:H:o:s:l:vkhwDa:p:', \%Opt) || Usage();

Usage() if (defined($Opt{h})); # Usage

# print help information
sub Usage {
  print "\n";
  print "  BARRACODA\n";
  print "  by Andrea Marquard, April 2015\n\n";
  print "  Description: Analyse FASTQ file from sequencing of DNA barcodes\n\n";
  print "  Usage: $0 -f <FASTQ-file> -t <tag-dir> -m <sample-map-file>\n\n";
  print "  Required arguments:\n";
  print "  -f   FASTQ file\n";
  print "  -m   File with mappings from sample ID tag names to sample names\n";
  print "  -A   FASTA file with sample tags\n";
  print "  -B   sequence of forward primer A\n";
  print "  -C   length of N-sequence (A end)\n";
  print "  -D   FASTA file with epitope A tags\n";
  print "  -E   sequence of annealing region\n";
  print "  -F   FASTA file with epitope B tags\n";
  print "  -G   length of N-sequence (B end)\n";
  print "  -H   sequence of forward primer B\n";
  print "\n";
  print "  Options:\n";
  print "  -a   Text file with barcode annotations\n";
  print "  -p   Excel sheet with barcode plate layouts\n";
  print "  -o   Output directory. Default: 'pwd'\n";
  print "  -s   Storage directory. Default: /home/tuba/marquard/mhc_barcodes/archive/barracoda_<pid>\n";
  print "  -t   Temporary directory. Default: /dev/shm\n"; # NEW LINE
  print "  -v   Verbose. Default: 'Off'\n";
  print "  -l   Logfile, if -v is defined. Default: 'STDERR'\n";
  print "  -k   Keep temporary directory. Default: 'Off'\n";
  print "  -w   web predictions. Default: 'Off'\n";
  print "  -h   Print this help information\n";
  print "\n";
  print "  Details:\n";
  PrintList("  -m   ", "File with mappings from sample ID tag names to sample names. 1st column: sequence IDs, like those found in the corresponding fasta file. 2nd column: the desired name of this sample. Leave name blank for unused sequence tags. And use identical names for replicates. Control samples must be named 'input'");
  print "\n";
  exit;                              
}


$verbose = 1 if defined($Opt{v});
$wwwmode = 1 if defined($Opt{w});
$cleanup = 0 if defined($Opt{k});

# In www mode, redirect errors to stdout, so they can be seen by the webservice user.
# Also check that user has accepted Terms and Conditions.
if($wwwmode == 1) {
   $verbose = 1;
   *STDERR=*STDOUT;
   $barracoda_path = '/tools/src/barracoda-' . $version;  
   # die("Cannot run webservice if user does not agree to Terms and Conditions.\n") unless $Opt{D}; 
} else {
   $barracoda_path = $barracoda_path;
}


#######################
#     USER OPTIONS    #
#######################

my $read_file  = $Opt{f} || MissingInput("FASTQ/FASTA file of sequencing reads");
my $smap       = $Opt{m} || MissingInput("Sample id map file");

## Check input is there and that it is meaningful
# die ("# File $read_file cannot be found.")    if (! -e $read_file);
# die ("# File $smap cannot be found.")         if (! -e $smap);


my $SAMPLE_FASTA   = $Opt{A} || MissingInput("FASTA file with sample tags");
my $PRIM_A_SEQ     = $Opt{B} || MissingInput("sequence of forward primer A");
my $N_A_LENGTH     = $Opt{C} || MissingInput("length of N-sequence (A end)");
my $EPI_A_FASTA    = $Opt{D} || MissingInput("FASTA file with epitope A tags");
my $ANNEAL_SEQ     = $Opt{E} || MissingInput("sequence of annealing region");
my $EPI_B_FASTA    = $Opt{F} || MissingInput("FASTA file with epitope B tags");
my $N_B_LENGTH     = $Opt{G} || MissingInput("length of N-sequence (B end)");
my $PRIM_B_SEQ     = $Opt{H} || MissingInput("sequence of forward primer B");

foreach my $file (($read_file, $smap, $SAMPLE_FASTA, $EPI_A_FASTA, $EPI_B_FASTA)) {
  die ("# File $file cannot be found.")         if (! -e $file);
}

foreach my $seq (($PRIM_A_SEQ, $ANNEAL_SEQ, $PRIM_B_SEQ)) {
  die ("# Pasted sequence $seq contains non-base characters.")  unless $seq =~ m/^[ACTG]+$/;
}

foreach my $num (($N_A_LENGTH, $N_B_LENGTH)) {
  die ("# Invalid length provided ($num)")  unless $num =~ m/^\d+$/;
}


## Barcode annotation file
my $ANNO_FILE     = $Opt{a} || MissingInput("Barcode annotation file");

# my $ANNO_FILE = "";
# if (defined($Opt{a})){
#   $ANNO_FILE = $Opt{a});
# }

## Barcode plate layout file
my $PLATE_FILE     = $Opt{p} if defined($Opt{p});


#######################
#     OUTPUT DIRS     #
#######################


## Temporary files
my $outDir = $machine eq 'tuba' ? "/dev/shm" : "$workingDir/tmp";
$outDir .= "/barracoda_$$";
# my $outDir = $workingDir."/barracoda_$$/tmp";

# NEW LINE 
$outDir = $Opt{t} if defined($Opt{t});

## Result files
my $resultDir = $workingDir."/barracoda_$$";
$resultDir = $Opt{o} if defined($Opt{o});
if ($wwwmode == 1) {
  unless (-d $wwwTempRootDir) {
    ### This error will never be invoked, because athena cannot even run this script if the mount is no longer working!!!
    # email
    Email("Failure report from CBS webserver.", "It appears that Athena's drives are no longer mounted on tuba.\r\nThis prevented Barracoda from running from the webserver.\r\nThe error occurred while running process id $$.\r\n");
    # die
    die ("# There is currently a network problem that interrupted Barracoda. We are working on fixing this. Please try again later. Feel free to email us, if you want to be updated when Barracoda is running again.\n")
  }
  $resultDir = "$wwwTempRootDir/$wwwTempDir";
}

## Storage of results/files
#my $storageDir = $machine eq 'tuba' ? "/home/tuba/marquard/mhc_barcodes/archive/barracoda_$$" : "$workingDir/storage/barracoda_$$";
my $storageDir = "$workingDir/storage/barracoda_$$";

if ($machine eq "tuba") {
  $storageDir = "/home/tuba/marquard/mhc_barcodes/archive/barracoda_$$";
} elsif (index($machine, "healthtech.dtu.dk")) {
  $storageDir = "$wwwTempRootDir"."/services/Barracoda-"."$version"."/tmp/storage_$$";
}

$storageDir = $Opt{s} if defined($Opt{s});

## Check that any of the dirs dont already exist. That means a pid has been reused.
if( -d $resultDir || -d $outDir || -d $storageDir ){
    if($wwwmode) {
      die("An unexpected (and rare) error occured (your job was given a process ID that was previously used for another Barracoda run).\nIt will most likely be fixed by simply running your job again.\n");
      } else {
      die("One of the output directories already exists.\n");        
      }
}

## Make dirs
`mkdir -p $resultDir`;
`mkdir -p $outDir`;
`mkdir -p $storageDir`;

print '$resultDir: ',$resultDir,"\n";
print '$outDir: ',$outDir,"\n";
print '$storageDir: ',$storageDir,"\n";

# ## Make sure the temp dir is deleted upon end of program
END { 
 if ($cleanup == 1) {
     print STDERR "Removing temporary files...";
     system("rm -rf $outDir");
  }
}
# END { 
#   if ($cleanup == 1) {
#     if ($? == 1) {
#       print STDERR "Unexpected exit: Removing temporary files and results";
#       &cleanup(($outDir, $resultDir))
#     }
#     else { &cleanup($outDir) }
#   }
# }

## Log file
my $logFile;
if (defined($Opt{l})){
  $logFile = $Opt{l};
  open(LOG, ">", $logFile) or die "# Cannot write file $logFile\n";
}
# If cleanup is disabled, make log file and be verbose no matter what:
elsif ($cleanup == 0 or $wwwmode or $verbose) {
  $verbose = 1;
  $logFile = "$outDir/log";
  open(LOG, ">", $logFile) or die "# Cannot write file $logFile\n";
}



###############################################################################
#                                      MAIN                                   #
###############################################################################

if ($verbose == 1){
    print LOG "# $command\n";
    print LOG "Started ", scalar(localtime()), "\n";
    print LOG "# Output temp-dir: $outDir\n";
    print LOG "# Output result-dir: $resultDir\n";
    print LOG "# Current dir: $workingDir\n";
}


###############################################################################
#                         CHECK INPUT FILES                                   #
###############################################################################
# run_R("Check barcode annotation file", "check-annotation-file.R", $ANNO_FILE);



###############################################################################
###                 INITIALISE  STATS                                       ###
###############################################################################

### ALIGNMENT STATS
#
# How many reads aligned to primer A? # How many aligned to the annealing region?
# etc...

my %STATS = ();
my $lines = 0;


###############################################################################
###          PARSE FASTA FILES, SEQUENCES AND LENGTH                     ######
###############################################################################

mkdir "$outDir/fasta";

my @start = (0)x8;
$start[1] = Fasta2FastaWithPos( $SAMPLE_FASTA, "$outDir/fasta/sample.fa", 0);
$start[2] = Seq2FastaWithPos(   $PRIM_A_SEQ,   "$outDir/fasta/primA.fa",  $start[1], "primA");
$start[3] = $N_A_LENGTH + $start[2];
$start[4] = Fasta2FastaWithPos( $EPI_A_FASTA,  "$outDir/fasta/epiA.fa",   $start[3]);
$start[5] = Seq2FastaWithPos(   $ANNEAL_SEQ,   "$outDir/fasta/anneal.fa", $start[4], "anneal");
$start[6] = Fasta2FastaWithPos( $EPI_B_FASTA,  "$outDir/fasta/epiB.fa",   $start[5]);
$start[7] = $N_B_LENGTH + $start[6];
$start[8] = Seq2FastaWithPos(   $PRIM_B_SEQ,   "$outDir/fasta/primB.fa",  $start[7], "primB");

my %len = ();
$len{sample} = $start[1] - $start[0];
$len{primA}  = length $PRIM_A_SEQ; # or $start[2] - $start[1];
$len{epiA}   = $start[4] - $start[3];
$len{anneal} = length $ANNEAL_SEQ; # or $start[5] - $start[4];
$len{epiB}   = $start[6] - $start[5];
$len{primB}  = length $PRIM_B_SEQ; # or $start[8] - $start[7];

if ($verbose == 1){
    print LOG "\nBarcode structure of a read:\n";
    print LOG "#   ", $start[0]+1, " .. ", $start[1], "   Sample barcode\n";
    print LOG "#   ", $start[1]+1, " .. ", $start[2], "   Primer A\n";
    print LOG "#   ", $start[2]+1, " .. ", $start[3], "   N6\n";
    print LOG "#   ", $start[3]+1, " .. ", $start[4], "   Peptide barcode A\n";
    print LOG "#   ", $start[4]+1, " .. ", $start[5], "   Annealing region\n";
    print LOG "#   ", $start[5]+1, " .. ", $start[6], "   Peptide barcode B\n";
    print LOG "#   ", $start[6]+1, " .. ", $start[7], "   N6\n";
    print LOG "#   ", $start[7]+1, " .. ", $start[8], "   Primer B\n";
}




###############################################################################
###      CHECK THAT SAMPLE IDS MATCH IN FASTA AND IN SAMPLE MAP FILE       ####
###############################################################################

print LOG "Checking that sample IDs match in sample-map file and FASTA file\n"  if $verbose;

# important to use the user's original sample fasta file, and not the intermediate one we've created, because we've added the positions to the fasta headers in this file.
system("$R --vanilla --slave --args $smap $SAMPLE_FASTA < $barracoda_path/scripts/check-sample-ids.R > $outDir/check-sample-IDs.R.out 2>&1") == 0
  or print LOG "---> Sample id check in R FAILED!!\n";

# die if there were errors (and print the log file)
PrintLogIfError("$outDir/check-sample-IDs.R.out");

print "1) Run check-sample-IDs.R.out\n";

###############################################################################
###          BUILD BOWTIE DATABASES                                 ###########
###############################################################################
mkdir("$outDir/databases") unless (-d "$outDir/databases");

foreach my $tag (("primA", "epiA", "anneal", "epiB", "primB")) {
  my $file = "$outDir/fasta/$tag.fa";
  if (-e $file) {
      mkdir("$outDir/databases/$tag");
      system("$bowtie2Build -f $file $outDir/databases/$tag/tag &> $outDir/databases/$tag/build.log");
      ## add --noref for performance gain # note: didn't work to align with newest version of bowtie when I used --noref
  } else { die("Could not find file $file when building bowtie2 databases\n"); }
}

print "2) Run Bowtie\n";

###############################################################################
###          DETERMINE INPUT FILE TYPE                              ###########
###############################################################################

# is fastq file zipped?
my $fastx_type = `file -b --mime-type $read_file`;

if ($fastx_type =~ m/zip/) {
  print LOG "Read file appears to be compressed, and I will attempt to unzip it using gzip\n"  if $verbose == 1;
  `gzip -kdc $read_file > $outDir/unzipped_reads.fastx`;
  $read_file = "$outDir/unzipped_reads.fastx";
}

my $fastx_format = `$barracoda_path/scripts/detect-fastx-format.pl $read_file`;
die "Input file is neither FASTA nor FASTQ format\n" unless $fastx_format eq 'fasta' || $fastx_format eq 'fastq'; 



###############################################################################
###          ENSURE FASTQ IDS ARE SORTED                            ###########
###############################################################################

  # paste four lines of FASTQ entry together
  # sort by id
  # change tabs back in to newlines to regain FASTQ format
my $sorted_reads = "$outDir/sorted.$fastx_format";
if ($fastx_format eq 'fasta') {
  system("cat $read_file | paste - - | sort -k1,1 -t ' ' | tr '\t' '\n' > $sorted_reads");
} else {
  system("cat $read_file | paste - - - - | sort -k1,1 -t ' ' | tr '\t' '\n' > $sorted_reads");
}

# Get read count for summary stats:
$lines = `cat $sorted_reads | wc -l`;
$STATS{total} = $fastx_format eq 'fastq' ? $lines / 4 : $lines / 2;

# How long were the reads?
system("$barracoda_path/scripts/$fastx_format-lengths.pl $sorted_reads > $outDir/lengths1.txt");         # All reads



###############################################################################
#### ALIGN ALL READS TO CONSTANT SEQS (anneal, fwd primer A, fwd primer B)  ###
###############################################################################

###  ALIGN TO ANNEALING SEQUENCE
#
my $dbDir = "$outDir/databases";

Bowtie($sorted_reads, "anneal", $outDir, {'--un' => "$outDir/anneal/un.$fastx_format", "--score-min" => "C,$len{anneal}", "--norc" => ''});

Bowtie($sorted_reads, "primA", $outDir, {'--un' => "$outDir/primA/un.$fastx_format", "--score-min" => "C,$len{primA}", "--norc" => ''});

Bowtie($sorted_reads, "primB", $outDir, {'--un' => "$outDir/primB/un.$fastx_format", "--score-min" => "C,$len{primB}", "--nofw" => ''});

# Delete fastq to minimize footprint
system("rm $sorted_reads");

###############################################################################
###    CONTINUE WITH THOSE READS THAT ALIGNED TO 2 OUT OF 3               #####
###############################################################################
my $sorted_reads_filter = "$outDir/filter.$fastx_format";

system("$barracoda_path/scripts/make-fastq-from-sam.pl $outDir/primA/aligns.sam $outDir/primB/aligns.sam $outDir/anneal/aligns.sam 2 $fastx_format > $sorted_reads_filter");

# Get read count for summary stats:
$lines = `cat $sorted_reads_filter | wc -l`;
$STATS{'2-of-3'} = $fastx_format eq 'fastq' ? $lines / 4 : $lines / 2;

# How long were the reads?
system("$barracoda_path/scripts/$fastx_format-lengths.pl $sorted_reads_filter > $outDir/lengths2.txt");  # After filtering "2 of 3"



###############################################################################
####   ALIGN FILTERED READS TO PEPTIDE BARCODES (peptide A, peptide B)      ###
###############################################################################

### ALIGN TO PEPTIDE TAG A
#
Bowtie($sorted_reads_filter, "epiA", $outDir, {"--no-unal" => '', "--score-min" => "C,$len{epiA}", "--norc" => ''});
# D has to be higher when there are that many more sequences in the reference database. ## NB: not after I changed seed length to 10, and allow for mismatches.

Bowtie($sorted_reads_filter, "epiB", $outDir, {"--no-unal" => '', "--score-min" => "C,$len{epiB}", "--nofw" => ''});
# D has to be higher when there are that many more sequences in the reference database ## NB: not after I changed seed length to 10, and allow for mismatches.
# --nofw needs to be set, then we only search the reverse complement. (alternatively I should have rev comp'ed the tag sequences)

# Delete fastq to minimize footprint
system("rm $sorted_reads_filter");


###############################################################################
#####    MERGE ALIGNMENTS FROM PEP A AND PEP B                            ##### 
###############################################################################
my $sam = "$outDir/merged.sam";
system("$barracoda_path/scripts/merge-sam-by-read-ID.pl $outDir/epiA/aligns.sam $outDir/epiB/aligns.sam > $sam");



###############################################################################
###  MAP THE CONSTANT SEQS AND BARCODES WITHIN EACH READ                  #####
###############################################################################
### This way we can locate sample ID and N6 sequences
my $mapped_reads = "$outDir/merged.mapped.reads.txt";
### Do it in parallel to save time
#
if (-e $parallel) {
  my $lines = `cat $sam | wc -l`;
  my $njobs = 10;
  my $chunk_size = 1 + int($lines / $njobs);

  system("rm -rf $outDir/chunks");
  system("mkdir $outDir/chunks");
  system("$split -l $chunk_size $sam $outDir/chunks/");
  system("ls -1 $outDir/chunks | $parallel --joblog $outDir/barcodesort.joblog.lg -j $njobs '$barracoda_path/scripts/dissect-barcodes--fast.pl $outDir/chunks/{} $outDir/fasta > $outDir/chunks/{}.mapped.reads.txt 2> $outDir/chunks/{}.log'");
  ### Combine results in one file.
  # only print when it's the first file or when it's past the first line.
  # That way we only get the header once in all.
  #
  system("$awk 'NR==1 || FNR>1' $outDir/chunks/[a-z][a-z].mapped.reads.txt > $mapped_reads");
} else {
  system("$barracoda_path/scripts/dissect-barcodes--fast.pl $sam $outDir/fasta > $mapped_reads");
}

# Get read count for summary stats:
$STATS{'A-and-B'} = `cat $sam | wc -l`;
chomp $STATS{'A-and-B'};

# How long were the reads?
system("cut -f4 $sam | $barracoda_path/scripts/stdin-lengths.pl > $outDir/lengths3.txt");                # After filtering "A and B"



###############################################################################
###                   STATS                                                 ###
###############################################################################

# How many reads aligned to primer A? etc...

foreach my $tag (("primA", "primB", "anneal", "epiA", "epiB")) {
  open(IN, "<", "$outDir/$tag/log") or die "Cannot open file $outDir/$tag/log";
  my ($total, $unal);
  while (defined(my $line = <IN>)) {
    $total = $1 if $line =~ m/^(\d+) reads; of these:/;
    $unal  = $1 if $line =~ m/(\d+) \(.+\%\) aligned 0 times/;
  }
  close IN;
  $STATS{$tag} = $total - $unal;
}

mkdir "$outDir/results";

open(OUT, ">", "$outDir/results/alignment-stats.txt") or die "Cannot write to file alignment-stats.txt\n";
print OUT "filter",  "\t", "num_of_reads",    "\t", "total_num_of_reads",    "\n";
print OUT "total",   "\t", $STATS{total},     "\t", $STATS{total},           "\n";
print OUT "primA",   "\t", $STATS{primA},     "\t", $STATS{total},           "\n";
print OUT "primB",   "\t", $STATS{primB},     "\t", $STATS{total},           "\n";
print OUT "anneal",  "\t", $STATS{anneal},    "\t", $STATS{total},           "\n";
print OUT "2-of-3",  "\t", $STATS{'2-of-3'},  "\t", $STATS{total},           "\n";
print OUT "epiA",    "\t", $STATS{epiA},      "\t", $STATS{'2-of-3'},        "\n";
print OUT "epiB",    "\t", $STATS{epiB},      "\t", $STATS{'2-of-3'},        "\n";
print OUT "A-and-B", "\t", $STATS{'A-and-B'}, "\t", $STATS{'2-of-3'},        "\n";
close OUT;



### READ STATS
#


###############################################################################
###                   SUMMARIZE IN R, AND PLOT                              ###
###############################################################################

print LOG "Starting R calculations ", scalar(localtime()), "\n"  if $verbose;

# Plot the distribution of read lengths, and compared to the expected length
# Expected length is based on the different sequences given by the user (primers, barcodes etc...)
run_R("Read length distribution analysis", "plot-read-lengths.R", "$outDir/lengths1.txt", "$outDir/lengths2.txt", "$outDir/lengths3.txt", "$outDir/results", $start[$#start]);

print "3) Run plot-read-lengths.R\n";

# The main script that generates results.
# Performs clonality reduction, compares to contorl samples and determines enriched barcodes
# Makes a range of plots and prints a bunch of tables/spreadsheets
run_R("Count analysis", "summarize-barcodes.R", $mapped_reads, $smap, "$outDir/results", "$outDir/fasta/epiA.fa" , "$outDir/fasta/epiB.fa", $N_A_LENGTH, $N_B_LENGTH, $ANNO_FILE);
print "4) Run summarize-barcodes.R\n";

# collect the pvals and logfc from all samples of an experiment in one table
run_R("Collecting p-values and log_fc values across samples", "collect-pvals-and-logfc.R", "$outDir/results");
print "5) Run collect-pvals-and-logfc.R\n";

if (defined($PLATE_FILE)) {
  # plot values on a layout determined by the plates used in the lab
  run_R("Plate view of barcodes", "plot-barcodes-on-plates.R", "$outDir/results", $PLATE_FILE, $ANNO_FILE) if defined($Opt{p});
}
print "6) Run plot-barcodes-on-plates.R\n";


###############################################################################
#                      Store results on tuba                                  #
###############################################################################

# Copy results and a few intermediary files to storage on tuba

# need to know if anno file is txt or xlsx? so I get the suffix
my $annosuffix = "txt";
my $annotype =`file -b $ANNO_FILE`;
if ($annotype =~ m/Microsoft/i || $annotype =~ m/Excel/i) {
  $annosuffix = "xlsx";
}

# same for sample key map
my $smapsuffix = "txt";
my $smaptype =`file -b $smap`;
if ($smaptype =~ m/Microsoft/i || $smaptype =~ m/Excel/i) {
  $smapsuffix = "xlsx";
}

# logs
system("mkdir $storageDir/logs");
system("cp $logFile $storageDir/logs/");
system("cp $outDir/*.out $storageDir/logs/");
system("cp $outDir/*.log $storageDir/logs/");

# results and mapped reads
system("cp -r $outDir/results $storageDir/");
system("cp $mapped_reads $storageDir/");

# input files uploaded by user (except the sequencing reads - too big)
system("mkdir $storageDir/input");
system("cp $smap $storageDir/input/sample-key-map.$smapsuffix");
system("cp $SAMPLE_FASTA $storageDir/input/sample.fasta");
system("cp $EPI_A_FASTA $storageDir/input/epitopeA.fasta");
system("cp $EPI_B_FASTA $storageDir/input/epitopeB.fasta");

system("cp $ANNO_FILE $storageDir/input/annotations.$annosuffix");
system("cp $PLATE_FILE $storageDir/input/plates.xlsx") if defined($PLATE_FILE);

# intermediate FASTA files
system("cp -r $outDir/fasta $storageDir/");



###############################################################################
#                      Read results, and show/print/plot them                 #
###############################################################################

# Copy results to result dir:
system("cp -r $outDir/results/* $resultDir/");

# remove some files (png images, txt files for which there are excel sheets, etc) before zipping dir to user
system("rm $outDir/results/*.png");
system("rm $outDir/results/experiment_*/*.png");
system("rm $outDir/results/experiment_*/graphs_*/*.png");
system("rm $outDir/results/*.All.txt");
system("rm $outDir/results/experiment_*/*.txt");
system("rm -rf $outDir/results/experiment_*/fold_change");
system("rm -rf $outDir/results/experiment_*/fold_change_by_MHC");
system("rm -rf $outDir/results/experiment_*/all-readcounts*");
system("rm $outDir/results/plate-setup/all-readcounts*");


# Zip all results into 1 file
## system("zip -rjq $resultDir/$$.barracoda-$version.zip $outDir/results");
# system("zip -rq $resultDir/$$.barracoda-$version.zip $outDir/results/*");
## system("tar -zcvf  $resultDir/$$.barracoda-$version.zip $outDir/results/");
system("cd $outDir; mv results barracoda_$$; zip -rq $resultDir/$$.barracoda-$version.zip barracoda_$$/*; mv barracoda_$$ results");
### TRY tar instead! but can windows users unzip a tar.gz file??


# print any warnings generated during the run
PrintWarnings($logFile) if ($verbose || $wwwmode);


if ($wwwmode) {
  # Start to print HTML output:
  #

  # horzontal line
  print "<hr>\n";

  print "<font face=\"ARIAL,HELVETICA\">\n";

  # All results (zipped)
  print "Actual version number used: $version\n";
  print "<p>";
  print "<a href=\"/$wwwTempDir/$$.barracoda-$version.zip\">Download all results as .zip file.</a>\n\n";

  # Barcode structure (as inferred from input info)
  print "<h2>Barcode structure of a read</h2>\n";
  print "</font>";
  print "<font face=\"COURIER\">";

  printf("Position  %3d .. %3d  => Sample barcode\n",    $start[0]+1, $start[1]);
  printf("Position  %3d .. %3d  => Primer A\n",          $start[1]+1, $start[2]);
  printf("Position  %3d .. %3d  => N6\n",                $start[2]+1, $start[3]);
  printf("Position  %3d .. %3d  => Peptide barcode A\n", $start[3]+1, $start[4]);
  printf("Position  %3d .. %3d  => Annealing region\n",  $start[4]+1, $start[5]);
  printf("Position  %3d .. %3d  => Peptide barcode B\n", $start[5]+1, $start[6]);
  printf("Position  %3d .. %3d  => N6\n",                $start[6]+1, $start[7]);
  printf("Position  %3d .. %3d  => Primer B\n",          $start[7]+1, $start[8]);

  print "</font><font face=\"ARIAL,HELVETICA\">\n";


  # barplot with read lengths
  my ($w, $h) = GetImageSize("$resultDir/read-lengths.pdf");

  print "<p>\n";
  print "<h2>Summary of data and analysis</h2>\n";
  print "<h4>NGS read lengths</h4>\n";
  print "<a href=\"/$wwwTempDir/read-lengths.pdf\">";
  print "<IMG SRC=\"/$wwwTempDir/read-lengths.png\" height=\"", $h*1.5, "\" width = \"", $w*1.5, "\">";
  print " [Click image to enlarge]</a>\n\n";


  # distribution of reads across keys (all keys on chip)
  ($w, $h) = GetImageSize("$resultDir/total-reads-per-key.pdf");

  print "<h4>Distribution of reads among sample keys</h4>\n";
  print "<a href=\"/$wwwTempDir/total-reads-per-key.pdf\">";
  print "<IMG SRC=\"/$wwwTempDir/total-reads-per-key.png\" height=\"", $h*1.5, "\" width = \"", $w*1.5, "\">";
  print " [Click image to enlarge]</a>\n\n";

  # statistics
  print "<h4>Barcode contents of NGS reads</h4>";
  print "</font><font face=\"COURIER\">";
  printf("%9d reads in total, of which\n", $STATS{total});
  printf("%9d reads contained the primer A sequence,\n", $STATS{primA});
  printf("%9d reads contained the primer B sequence,\n", $STATS{primB});
  printf("%9d reads contained the annealing sequence.\n\n", $STATS{anneal});
  printf("%9d reads contained 2 out of 3 of the above sequences, and of these:\n", $STATS{'2-of-3'});
  printf("%9d reads matched an A epitope\n", $STATS{epiA});
  printf("%9d reads matched a B epitope\n", $STATS{epiB});
  printf("%9d reads matched both an A and a B epitope, and were used for the analysis.\n", $STATS{'A-and-B'});

  print "</font><font face=\"ARIAL,HELVETICA\">\n";

  print "<a href=\"/$wwwTempDir/alignment-stats.txt\">Download as .txt</a>\n";
  # print "</PRE>\n";

  print "</font>\n";
}



###############################################################################
#                             CLEAN UP                                        #
############################################################################### 

# Remove temporary files
system("rm -rf $outDir") if $cleanup;

print LOG "Finished ", scalar(localtime()), "\n" if $verbose;


###############################################################################
#                                 END OF PROGRAM                              #
###############################################################################
print "DONE\n";
exit(0);



###############################################################################
#                             SUB-ROUTINES SECTION                            #
############################################################################### 


sub run_R {
  my ($analysis_name, $script, @args) = @_;
  
  my $script_path = "$barracoda_path/scripts/$script";
  
  my $fun_script = "$barracoda_path/scripts/functions.R";
  
  my $args = join(" ", @args);

  my $cmd = "$R --vanilla --slave --args $args < <(cat $fun_script $script_path) > $outDir/$script.out 2>&1";
  
  if(system_bash($cmd) == 0) {
      print LOG "$analysis_name in R complete.\n";
    } else {
      print LOG "---> $analysis_name in R FAILED!!\n";
  }

  PrintWarnings("$outDir/$script.out");
  PrintErrors("$outDir/$script.out") && exit(0);

}


sub system_bash {
  # 'shift' will shift the input array @_ and return the first elem, so you might as well have used $_
  my @args = ( "bash", "-c", shift );
  system(@args);
}


sub Email {
  my ($subject, $text) = @_;
  open(OUT, "|-", '/usr/sbin/sendmail barracoda@cbs.dtu.dk') or die "Cannot send email\n";
  # Mail headers
  print OUT "Subject: $subject\r\n";
  print OUT "From: barracoda\@cbs.dtu.dk\r\n\r\n";
  # mail content
  print OUT $text;
  print OUT "\r\n";
  close OUT;
}

sub MissingInput {
  my $message = "COULD NOT RUN SCRIPT FOR THE FOLLOWING REASON:\n\n- Required input is missing: ".$_[0]."\n\nPlease add this input and try again.\n";
  if ($wwwmode) {
    die($message);
  } else {
    print STDERR $message;
    Usage();
  }
}

sub Bowtie {
  my ($file, $reg, $dir, $Args) = @_;
  system("rm -rf $dir/$reg");
  system("mkdir $dir/$reg");
  
  # Bowtie2 arguments:
  #   -N    number of mismatches allowed in seed alignment
  #   -i    interval between seed strings. L,a,b means f(x) = a + bx where x is read length
  #
  #   --mp MX,MN          Sets the maximum (MX) and minimum (MN) mismatch penalties, both integers. (depending on base quality)
  #   --np                Sets penalty for positions where the read, reference, or both, contain an ambiguous character such as N. Default: 1.
  #   --rdg <int1>,<int2> Sets the read gap open (<int1>) and extend (<int2>) penalties. A read gap of length N gets a penalty of <int1> + N * <int2>. Default: 5, 3.
  #   --rfg <int1>,<int2> Sets the reference gap open (<int1>) and extend (<int2>) penalties. A reference gap of length N gets a penalty of <int1> + N * <int2>. Default: 5, 3.
  #   --score-min <func>  Sets a function governing the minimum alignment score needed for an alignment to be considered "valid" (i.e. good enough to report).
  #
  #
  # Scoring in local mode:
  #   +2  (--ma)  base match
  #   -6  (--mp)  mismatch at high quality position
  #   -5  (--rdg and --rfg)  gap open
  #   -3  (--rdg and --rfg)  gap extension
  #   
  # Default arguments:
  my %CmdArgs = ('-L' => 10,
              '-N' => 1,
              '-i' => 'L,1,0',
              # '-D' => 150,
            '--al' => "$dir/$reg/al.$fastx_format",
              '-p' => 10,
       '--reorder' => '',
              '-t' => '',
              '-x' => "$dbDir/$reg/tag",
         '--local' => '',
              '-U' => '-',
              '-S' => "$dir/$reg/aligns.sam",
         '--no-hd' => ''
            );

  if ($fastx_format eq 'fasta') {
    $CmdArgs{'-f'} = '';
  }
  ## FASTQ is default
  # if ($fastx_format eq 'fastq') {
    # $CmdArgs{'-q'} = '';
  # }

  # Overwrite with user arguments
  foreach my $arg (keys %{$Args}) {
    $CmdArgs{$arg} = ${$Args}{$arg};
  }

  # Concatenate bowtie command
  my $cmd = "cat $file | $bowtie2";
  foreach my $arg (reverse sort keys %CmdArgs) {
    $cmd .= " $arg";
    $cmd .= " $CmdArgs{$arg}" unless $CmdArgs{$arg} eq '';
  }
  $cmd .= " 2> $dir/$reg/log";

  # Run it
  AppendToFile($cmd, "$outDir/bowtie.commands.log");
  #print LOG "# Bowtie2 command: $cmd\n\n" if $verbose;
  system($cmd);

  # clean up after, to minimize storage footprint
  # delete anything except the log file which doesn't have a suffix)
  system("rm -rf $dir/$reg/*.$fastx_format");

}



sub PrintList {
  my ($item, $text) = @_;
  my $n = length $item;
  my $w = 80-$n;
  
  my ($new_i, $use_w) = AvoidWordBreak($text, 0, $w);
  print $item, substr($text, 0, $use_w), "\n";

  for (my $i = $new_i+$w; $i < length($text); $i += $w) {
    my ($new_i, $use_w) = AvoidWordBreak($text, $i, $w);
    print " "x$n, substr($text, $i, $use_w), "\n";
    $i = $new_i;
  }
}

sub AvoidWordBreak {
  my ($str, $pos, $len) = @_;
  my $s = rindex(substr($str, $pos, $len), " ");
  unless ($s == $len-1 or $pos+$len > length($str)) {
    my $use_len = $s;
    my $new_pos = $pos - ($len - $s - 1);
    return($new_pos, $use_len);
  } else {
    return($pos, $len);
  }
}



sub Fasta2FastaWithPos {
  # positions will be 0-indexed
  my ($old_file, $new_file, $start) = @_;
  my ($len, $end, $next_start) = -1;
  open(OUT, ">", $new_file) or die "Cannot write to file $new_file\n";
  open(IN, "<", $old_file) or die "Cannot open file $old_file\n";
  my $line;
  while (defined($line = <IN>) && $line =~ m/^(>\S*)/) {
    my $id = $1;
    my $seq;
    if (defined($line = <IN>) && $line =~ m/^([ACTG]+)\s?$/) {
      $seq = $1;
    } else { die "Corrupt FASTA format at line $. in file $new_file\n"; }
    if ($len == -1) {
      $len = length $seq;
      $end = $start + $len - 1;
      $next_start = $end + 1;  
    } else {
      die "Inconsistent sequence lengths when generating $new_file\n" unless length($seq) == $len;
    }
    $id .= " $start $end";
    print OUT "$id\n$seq\n";
  }
  die "Corrupt FASTA format at line $. in file $new_file\n" if (defined($line = <IN>));
  close OUT;
  close IN;
  die "Found no correct sequences in FASTA file when generating $new_file\n" if $len == -1;
  return($next_start);
}

sub Seq2FastaWithPos {
  # positions will be 0-indexed
  my ($seq, $newfile, $start, $id) = @_;
  my $end = $start + length($seq) - 1;
  $id =~ s/\s+/_/g;
  $id .= " $start $end";

  open(OUT, ">", $newfile) or die "Cannot write to file $newfile\n";
    print OUT ">$id\n$seq\n";
  close OUT;

  my $next_start = $end + 1; 
  return ($next_start);
}

sub GetImageSize {
  my ($pdf) = @_;
  my $figSize = `pdfinfo $pdf | grep "Page size:"`;
  my ($w, $h) = 0;
  if ($figSize =~ m/([0-9]+) x ([0-9]+)/) {
    $w = $1;
    $h = $2;
  }
  return($w, $h);
}

# If a log file contains lines with "ERROR" the entire log file will be printed to stdout, and perl will die.
sub PrintLogIfError {
  my ($logfile) = @_;
  if(system("grep -q ERROR $logfile") == 0) {
    open(IN, '<', $logfile) or die "Cannot read file $logfile\n";
    my @log = <IN>;
    close(IN);

    if ($wwwmode) {
      for (@log) {
        s|ERROR|<font color="red">ERROR</font>|;
      }
    }

    print @log;
    die;
  }
}

# If a log file contains lines with "WARNING" those lines will be printed to stdout.
sub PrintWarnings {
  my ($logfile) = @_;
  if(system("grep -q WARNING $logfile") == 0) {

    open(IN, "grep WARNING $logfile |") or die "Cannot read file $logfile\n";
    my @log = <IN>;
    close(IN);

    if ($wwwmode) {
      for (@log) {
        s|WARNING|<font color="red">WARNING</font>|;
      }
    }

    print @log;

  }
}


sub PrintErrors {
  my ($logfile) = @_;
  if(system("grep -q ERROR $logfile") == 0) {

    open(IN, "grep ERROR $logfile |") or die "Cannot read file $logfile\n";
    my @log = <IN>;
    close(IN);

    if ($wwwmode) {
      for (@log) {
        s|ERROR|<font color="red">ERROR</font>|;
      }
    }
    
    print @log;

    return(1);
  } else {
    return(0);
  }
}


# Print something to a file. such as a bowtie command, which is too messy to put in the log file, but nice to have for future ref
sub PrintToFile {
  my ($what, $file) = @_;
  open(OUT, ">", $file) or die "Cannot write to file $file\n";
  print OUT $what;
  close(OUT);
}
# same as PrintToFile, just appends instead
sub AppendToFile {
  my ($what, $file) = @_;
  open(OUT, ">>", $file) or die "Cannot write to file $file\n";
  print OUT "\n$what";
  close(OUT);
}




