#!/bin/bash

if [ $# -ne 2 ]
then
    echo "less/more than 2 argument was passed."
    exit 1
fi

writefile=$1
writestr=$2

mkdir -p "$(dirname "$writefile")" && echo "$writestr" > $writefile

if [ $? -ne 0 ]
then
    echo "Could not creating the file"
    exit 1
fi

