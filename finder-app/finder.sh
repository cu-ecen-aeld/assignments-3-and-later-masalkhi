#!/bin/sh

if [ $# -ne 2 ]
then
    echo "Not both argument was submitted."
    exit 1
fi

filesdir=$1
searchstr=$2

if [ -d "$filesdir" ]
then
    echo -n ""
else
    echo "The dir is not valid."
    exit 1
fi

X=$(find "$filesdir" -type f | wc -l)
Y=$(grep -r "$searchstr" "$filesdir" 2> /dev/null | wc -l)

echo "The number of files are $X and the number of matching lines are $Y"
