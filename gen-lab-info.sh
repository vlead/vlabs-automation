#!/bin/sh

########VARIABLES###################
VDOCROOT="/var/www"
CONF="$VDOCROOT/labs-info.html"
VHOST="vlead001"
VHOSTALIAS="emcee.virtual-labs.ac.in"
LOGDIR="logs"
HTMLSPACE="&nbsp;"
DEPLOYVERFILE="vlabs-version.txt"
####################################

#Customized echo function
vecho()
 {
   text=$1
   echo $text >> $CONF
 }

#Delete previous backup, backup existing configuration if present
  if [ -f $CONF.bak ] ; then
   rm -rf $CONF.bak
  fi
  if [ -f $CONF ] ; then
   mv $CONF $CONF.bak
  fi

#Get a list of all the containers and their IPs
vhost_list=$(vzlist -H -a -o ip,hostname -s hostname| sed 's/ \+/ /g')

#Start echoing static stuff to the configuration file
vecho " <html> "
vecho " <head> "
vecho " </head> "
vecho " <body> "
vecho " <table border='1' cellspacing='1' width='70%'>"
vecho " <tr> "
vecho " <td colspan=8> <b>Following are the list of labs and their information:</b></td> "
vecho " </tr> "
vecho " <tr> "
vecho " <td colspan=8> Last Full Deployment Date/Time:<b>$HTMLSPACE</b></td> "
vecho " </tr> "
vecho " <tr> "
vecho " <td colspan=8> Last Incremental Deployment Date/Time:<b>`date`$HTMLSPACE</b></td> "
vecho " </tr> "
vecho " <tr><td><b>Slno</b></td><td><b>Labid</b></td><td><b>LabIP</b></td><td><b>Deployment</b></td><td><b>Errors</b></td><td><b>VerInfo</b></td><td><b>Log</b></td><td><b>Testing</b></td></tr>"

#Echo dynamic stuff based on the list of containers
IFS=$'\n'
count=1
for vhost in $vhost_list ; 
do
 vhostip=`echo $vhost | cut -d' ' -f1`
 vhostname=`echo $vhost | cut -d' ' -f2`
 vhost=`echo $vhostname | cut -d'.' -f1`
 vdeployerrors=`grep VERROR $LOGDIR/$vhost.log | wc -l`
 if [ "$vdeployerrors" == "0" ] ; then
   vdeploystat="Success"
   vdeploystatcolor="#00FF00"
 else
   vdeploystat="Failure"
   vdeploystatcolor="#FF0000"
 fi

 vteststat=`grep ^VTEST $LOGDIR/$vhost.log | cut -d':' -f2 | sed 's/^ //'`
 if [ "$vteststat" == "Success" ] ; then
   vteststatcolor="#00FF00"
 else
   vteststat="Failure"
   vteststatcolor="#FF0000"
 fi

 if [ "$vhostname" != "" ] && [ "$vhostip" != "" ] ; then
    vecho "<tr>"
    vecho "<td>$count$HTMLSPACE</td><td><a href="$vhostname/">$vhostname$HTMLSPACE</a></td><td>$vhostip$HTMLSPACE</td><td bgcolor="$vdeploystatcolor">$vdeploystat$HTMLSPACE</td><td bgcolor="$vdeploystatcolor">$vdeployerrors$HTMLSPACE</td><td><a href="$LOGDIR/$vhost.log">View log$HTMLSPACE</a></td><td><a href="$vhostname/$DEPLOYVERFILE">View VerInfo$HTMLSPACE</a></td><td bgcolor="$vteststatcolor">$vteststat$HTMLSPACE</td>"
    vecho "</tr>"
    count=`expr $count + 1`
 fi
done

# End the configuration with static stuff
vecho " </table> "
vecho " </body> "
vecho " </html> "

# Restart Apache
#service httpd restart
