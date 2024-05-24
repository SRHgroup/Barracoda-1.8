#
# This script checks that the sample ids in the sample-key-map file match those found in the sample fasta file
#


################################
###  COMMAND LINE ARGUMENTS  ###
################################

smap_file     <- commandArgs(TRUE)[1]  # sample key map file
fasta_file    <- commandArgs(TRUE)[2]    # sample id fasta file


################################
###   READ AND COMPARE DATA  ###
################################


fasta_headers <- readLines(pipe(paste("grep '>'", fasta_file))) # Get the fasta header lines
fasta_headers <- sub("^>", "", fasta_headers) # remove leading arrow sign

smap_ids <- read.table(smap_file, sep = "\t", as.is = TRUE)[,1] # Get the sample IDs

if(all(smap_ids %in% fasta_headers)) {
  message("OK: All ids in sample-key-map file are present in the sample fasta file.")
} else {
  message(
    "ERROR: one or more ids in sample-key-map file are missing in the sample fasta file:\n",
    paste(smap_ids[!smap_ids %in% fasta_headers], collapse = "\n"),
    "\n\nPerhaps you formatted the keys differently?\nHere are the first few keys from the FASTA file, for comparison:\n",
    paste(head(fasta_headers), collapse = "\n")
    )
}






