if(!interactive()) {
	cArgs <- commandArgs(TRUE)
} else {
	cArgs <- "/home/tuba/marquard/git/Barracoda/webservice/test/in/annotations.error.txt"
}

annotations <- cArgs[1]

anno_list <- read.annotation(annotations)

for (i in 1:length(anno_list)) {
  anno <- anno_list[[i]]

  anno_name <- if(is.null(names(anno_list))) 1 else names(anno_list)[i]
  
  # check for duplicate barcodes
  dups <- duplicated(rownames(anno))
  
  if(any(dups)) {
    
    message("ERROR: Barcodes cannot be repeated in annotation file ",
            anno_name,
            ". Found one or more duplicated barcodes (",
            paste(anno[dups, 1], collapse = ", "),
            ")")
  }
  
  # check for HLA column
  hla <- grep("HLA", colnames(anno), value = TRUE)
  
  if(length(hla) == 0) {
  
      message("ERROR: Could not find HLA info in annotation file ",
            anno_name,
            ". All annotation files must include a column with HLA information. ", 
            "Make sure this column's header includes the word 'HLA' so that I can find it.")
  
    }
  
}
