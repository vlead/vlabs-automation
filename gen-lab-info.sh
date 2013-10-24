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
vecho " <tr><td><b>Slno</b></td><td><b>LabUrl</b></td><td><b>LabIP</b></td><td><b>BasicDeployment</b></td><td><b>VersionInfo</b></td><td><b>LabDeployment</b></td><td><b>Errors</b></td><td><b>Log</b></td></tr>"

#Echo dynamic stuff based on the list of containers
IFS=$'\n'
count=1
for vhost in $vhost_list ; 
do
 vhostip=`echo $vhost | cut -d' ' -f1`
 vhostname=`echo $vhost | cut -d' ' -f2`
 vhost=`echo $vhostname | cut -d'.' -f1`

 vdeployerrors=`grep VERROR $LOGDIR/$vhost.log | wc -l`
 vdeploystat=`grep ^VDEPLOY $LOGDIR/$vhost.log | cut -d':' -f2 | sed 's/^ //'`
 if [ "$vdeploystat" == "Success" ] ; then
   vdeploystat="Success"
   vdeploystatcolor="#00FF00"
   vdeployimg="success.jpg"
 elif [ "$vdeploystat" == "Failure" ] || [ "$vdeployerrors" != "0" ] ; then
   vdeploystat="Failure"
   vdeploystatcolor="#FF0000"
   vdeployimg="failure.png"
 else
   vdeploystat="Unknown"
   vdeploystatcolor="#0000FF"
   vdeployimg="progress.gif"
 fi

 vteststat=`grep ^VTEST $LOGDIR/$vhost.log | cut -d':' -f2 | sed 's/^ //'`
 if [ "$vteststat" == "Success" ] ; then
   vteststatcolor="#00FF00"
   vtestimg="success.jpg"
 elif [ "$vteststat" == "Failure" ] ; then
   vteststat="Failure"
   vteststatcolor="#FF0000"
   vtestimg="failure.png"
 else 
   vteststat="Unknown"
   vteststatcolor="#0000FF"
   vtestimg="progress.gif"
 fi

 if [ "$vhostname" != "" ] && [ "$vhostip" != "" ] ; then
    vecho "<tr>"
    vecho "<td>$count$HTMLSPACE</td><td><a href="$vhostname/" target="_new">$vhostname$HTMLSPACE</a></td><td>$vhostip$HTMLSPACE</td><td><img src="$vtestimg" width="18" height="18">$vteststat$HTMLSPACE</td><td><a href="$vhostname/$DEPLOYVERFILE">View$HTMLSPACE</a></td><td><img src="$vdeployimg" width="18" height="18">$vdeploystat$HTMLSPACE</td><td bgcolor="$vdeploystatcolor">$vdeployerrors$HTMLSPACE</td><td><a href="$LOGDIR/$vhost.log" target="_new">View$HTMLSPACE</a></td>"
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
