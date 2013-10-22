#!/bin/sh


######################################################
# This script spawns parallel processes to read the 
# configuration files generated by "run-config.sh" 
# line by line and execute them while logging to 
# appropriate log files 
######################################################

##################GLOBALS#################
DOMAIN="local"
TESTSUBDOMAIN="test"
ENV="test"   # Leave it blank for production
CONFIGPREFIX="vlabs-cmds.conf"
LOGPREFIX="./logs/"
PARALLEL="2"
LOGLEVEL="1"
##########################################

# Error message if the script is not run with root privileges"
if [ "$USER" != "root" ] ; then
  echo " This script should be run with root privileges...Exiting"
  exit
fi

# Spawn parallel processes
execute_cmds()
 {
  IFS=$'\n'
  for cmd in $(cat $1);
  do
  # echo $cmd
   if [ "`echo $cmd | grep '^#'`" == "$cmd" ] ; then
    #This is a comment, parse arguments to get the hostname
    LOGFILE=$LOGPREFIX/$(echo $cmd | sed 's/#//g')
    if [ -f "$LOGFILE.log" ] ; then
      rm -rf $LOGFILE.log
    fi
   else
    #This is a command, just execute it and send output to the logfile
    if [ "$LOGLEVEL" = "1" ] ; then
      #Verbose logging
      echo "VDEBUG: Executing [[ $cmd ]] " >> $LOGFILE.log
    fi
    eval $cmd >> $LOGFILE.log 2>&1
    EXITSTATUS=$?
    if [ "$EXITSTATUS" != 0 ] ; then
      echo "VERROR: Error occured. Unable to continue" >> >> $LOGFILE.log
      break
    fi
   fi
  done
 }

i=0
while [ "$i" \< "$PARALLEL" ];  
do 
#  cat ./$CONFIGPREFIX.$i | while read cmd ; 
  execute_cmds ./$CONFIGPREFIX.$i & 
  i=`expr $i + 1`
done
