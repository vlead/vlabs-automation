#!/bin/sh

##################GLOBALS#################
DOMAIN="local"
TESTSUBDOMAIN="test"
ENV="test"   # Leave it blank for production
CONFIGPREFIX="vlabs-cmds.conf"
PARALLEL="4"
##########################################

# Spawn parallel processes
i=0
while [ "$i" \< "$PARALLEL" ];  
do 
  sh ./$CONFIGPREFIX.$i > $CONFIGPREFIX.$i.log 2>&1 &
  i=`expr $i + 1`
done
