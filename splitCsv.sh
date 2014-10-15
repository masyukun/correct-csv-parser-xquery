#!/bin/bash

# Get arguments from command-line
usage() { 
	echo USAGE: 
	echo "   $0 [-s NNN] [-h <true|false>] csv-filename1 [csv-filename2] [...] [csv-filenameN]"
	echo
	echo OPTIONS: 
	echo " -s = Maximum size of resulting pieces in MB"
	echo "      Example:  \(broken into 10 MB pieces\)"
	echo "                $0 -s 10 myfile.csv"
	echo
	echo ' -h = Header line presence: "true" or "false", no quotes.'
	echo "      Example:"
	echo "                $0 -s 10 -h false myfile.csv"
	echo
	echo  csv-filename = 1 or more filenames of a CSV file to split
	echo
	exit 1;
}

header=true
MILLION=1000000
while getopts ":s:h:" o; do
    case "${o}" in
        s)
            s=${OPTARG}
            ;;
        h)
			h=${OPTARG}
            (("$h" == "true" || "$h" == "false")) || usage
            if [ "$h" == "false" ]; then
            	echo "SPECIFIED: no header line for incoming CSV(s)."
            	header=false
            fi
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${s}" ]; then
    usage
fi

#echo "s = ${s}"
#echo "p = ${p}"


### Main loop to process files ###

while [ $# -ne 0 ]; do
  FILE=$1
  TEMPFILE=`basename $FILE`
  FILE_BASE=`echo "${TEMPFILE%.*}"`  #file without extension
  FILE_EXT="${TEMPFILE##*.}"  #file extension



  # Is that really a CSV file?
  if [[ $FILE_EXT != "csv" ]]
  then
  	echo ========================
  	echo "WARNING: Input file $FILE_BASE.$FILE_EXT does not have a .csv extension!"
  	echo ========================
  fi

  echo
  echo "Splitting $FILE_BASE.$FILE_EXT into $s MB pieces."

  read lines words characters filename <<< $(wc $FILE)
  if [[ characters -le $(($s * $MILLION)) ]]
  then
  	echo "SKIPPING: This file is only $characters bytes, so won't be split."
  	shift
  	continue
  fi

  echo "$lines lines."
  echo "$characters characters."

  pieces="$((1 + $(($characters / $(($s * $MILLION))))))"
  pieceLines="$(($pieces + $(($lines / $pieces))))"
  echo "$pieces pieces of $pieceLines lines each"

  # Write file headers
  for i in `seq 1 $pieces`
  do
  	outfile="$FILE-part$i.csv"
    echo "Writing $outfile..."
    eval "head -1 $FILE" > $outfile
    if [[ $i -eq 1 ]]; then
	    eval "awk 'NR >= 2 && NR <= $(($pieceLines * $i))' $FILE >> $outfile"
	else
	    eval "awk 'NR >= $(($(($pieceLines * $(($i - 1)))) + 1)) && NR <= $(($pieceLines * $i))' $FILE >> $outfile"
    fi
  done

#  for i in `seq 1 $lines`
#  do
#
#  	echo "Line $i/$pieceLines goes into file $FILE-part$((1 + $(($i / $pieceLines)))).csv"
#  done



  shift  #Move on to next input file.
done

### End main loop ###

exit 0
