#!/bin/bash
# run.sh: Splits FASTA and uploads it to S3
#
# Author: Christiam Camacho (camacho@ncbi.nlm.nih.gov)
# Created: Wed Jul  7 13:42:14 EDT 2021

#export PATH=/bin:/usr/local/bin:/usr/bin
set -xeuo pipefail
shopt -s nullglob

batch_len=5000000
show_help=0
copy_only=0
input=''
output_bucket=''
local_output_dir='/blast/queries'

while getopts "o:i:b:c:q:h" OPT; do
    case $OPT in 
        b) batch_len=${OPTARG}
            ;;
        o) output_bucket=${OPTARG}
            ;;
        h) show_help=1
            ;;
        i) input=${OPTARG}
            ;;
        q) local_output_dir=${OPTARG}
            ;;
        c) copy_only=${OPTARG}
            ;;
    esac
done

[ -z "$output_bucket" ] && { echo "Missing OUTPUT_BUCKET argument"; show_help=1; }
[ -z "$input" ] && { echo "Missing INPUT argument"; show_help=1; }

if [ $show_help -eq 1 ] ;then
    echo "Usage: $0 -i INPUT -o OUTPUT_BUCKET -b BATCH_LEN"
    exit 0
fi

TMP=`mktemp`
if [[ $output_bucket =~ ^s3:// ]]; then
  time fasta_split.py $input -l $batch_len -o output -c $TMP
  time aws s3 cp output $output_bucket/query_batches --recursive --only-show-errors
  time aws s3 cp $TMP $output_bucket/metadata/query_length.txt --only-show-errors
else
  if [ $copy_only -eq 1 ]; then
    time gsutil -mq cp "$output_bucket/query_batches/batch_*.fa" $local_output_dir
  else
    time fasta_split.py $input -l $batch_len -o $local_output_dir -c $TMP
    time gsutil cp $TMP $output_bucket/metadata/query_length.txt
    (cd $local_output_dir; ls batch_*.fa) | gsutil cp - $output_bucket/metadata/batch_list.txt
  fi
fi
