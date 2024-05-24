#!/bin/bash

###############################################################################
###                   STATS                                                 ###
###############################################################################
 
dir=$1
# echo "dir is $dir"

echo -n "total "
expr $(cat $dir/file_sorted.fast* | wc -l) / 4

for i in "primA" "primB" "anneal"; do
  echo -n $i
  tot=$(grep "^[0-9]\+ reads; of these:" $dir/$i/log | awk '{ printf " " $1 }')
  unal=$(grep "aligned 0 times" $dir/$i/log | awk '{ printf " " $1 }')
  echo " $(expr $tot - $unal)"
done

echo -n "2-of-3 "
expr $(cat $dir/filter.fast* | wc -l) / 4

for i in "epiA" "epiB"; do
  echo -n $i
  tot=$(grep "^[0-9]\+ reads; of these:" $dir/$i/log | awk '{ printf " " $1 }')
  unal=$(grep "aligned 0 times" $dir/$i/log | awk '{ printf " " $1 }')
  echo " $(expr $tot - $unal)"
done

echo -n "A-and-B "
cat $dir/merged.sam | wc -l