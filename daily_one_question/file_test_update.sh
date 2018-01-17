#!/bin/bash
# Day7
# Author: Aaron
# Description: Statistics within 5 minutes of newly uploaded files.
datadir='/data/web/attachment/'
date_now=`date +"%F-%H-%M"`

while :;do
    find ${datadir} -type f -mmin -5 -exec echo {} > ${date_now}.txt \;
    sleep 300
done
