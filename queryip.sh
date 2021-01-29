#!/usr/bin/env bash

# read json key/value pairs to variables
# (keys: servicename, region, domain, zoneid, logprefix, rootobject)
for kv in $(sed -n 's/"\(.*\)": "\(.*\)",\{0,1\}/\1:\2/p' config.json); do
	k=${kv%:*}
	v=${kv#*:}
	printf -v "$k" "%s" "$v"
done

# create new directories
mkdir -p logs/zipped/	  # zipped log files; synced to AWS s3 bucket
mkdir -p logs/unzipped/   # decompressed files which have already been processed
mkdir -p logs/processing/ # files currently being processed
mkdir -p logs/enriched/   # JSON data for each unique IP address processed in a batch

# create associative array of existing log files (will be used to exclude old files)
declare -A existing
for f in $(find logs/zipped -name "*.gz" -exec basename {} \;); do
	existing[$f]=""
done

# sync zipped log files from s3 log bucket
aws s3 sync s3://$domain-logs/$logprefix logs/zipped --exclude "*" --include "*.gz"

duplicates=0
newfiles=0
# unzip new files to directory to be processed
for f in $(find logs/zipped -name "*.gz" -exec basename {} \;); do
	if [[ -v existing[$f] ]]; then
		duplicates=$(( duplicates + 1 ))
	else
		newfiles=$(( newfiles + 1 ))
		fname=$(basename "${f}" .gz)
		gzip -d -c logs/zipped/$f >> logs/processing/$fname
	fi
done
echo "Decompressed ($newfiles) new files - Skipped ($duplicates) existing files"

if ((newfiles == 0)); then
	echo "No new log files: exiting..."
	exit
fi

# current date/time for unique file names
date=$(date "+%Y-%m-%d_%H_%M_%S")
# unique IP addresses in all unzipped files
ips=$(grep "([0-9]{1,3}[\.]){3}[0-9]{1,3}" logs/processing/* -E -o -h --exclude=*.gz | sort --unique)
# number of unique IP's
count=$(echo $ips | wc -w)

file=1 # number of file being written
n=0 # number of IP's in current "data" string
data="" # formatted IP string for curl

# query ip data for all unique IPs using ip-api.com
for ip in $ips; do
	n=$((n+1))
	count=$((count-1))
	if ((n == 1)); then # first IP address; no leading comma
		data="\"$ip\""
	else
		data+=", \"$ip\"" # separate following IP's with commas
	fi
	# query IP data in batches of 99 
	if ((n == 50 | count == 0)); then
		fname=$date-$file.json
		echo "Writing data for $n IP's to $fname"
		curl -s http://ip-api.com/batch --data "[$data]" >> logs/enriched/$fname
		data=""
		n=0
		file=$((file+1))
	fi
done

# move decompressed files to the processed files directory
mv logs/processing/* logs/unzipped/
