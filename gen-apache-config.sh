#!/bin/sh

########VARIABLES###################
CONF="/etc/httpd/conf.d/labs.conf"
VHOST="vlead001"
VHOSTALIAS="emcee.virtual-labs.ac.in"
VDOCROOT="/var/www"
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
vhost_list=$(vzlist -H -a -o ip,hostname -s hostname| sed 's/    //g')

#Start echoing static stuff to the configuration file
vecho "<VirtualHost *:80>           "
vecho "    ServerAdmin help@$VHOST"
vecho "    ServerName $VHOST"
vecho "    ServerAlias $VHOSTALIAS"
vecho "    DocumentRoot $VDOCROOT"
vecho "    ErrorLog logs/$VHOST-error_log"
vecho "    CustomLog logs/$VHOST-access_log combined"
vecho "    # Pass Proxy For labs"

#Echo dynamic stuff based on the list of containers
IFS=$'\n'
for vhost in $vhost_list ; 
do
 vhostip=`echo $vhost | cut -d' ' -f1`
 vhostname=`echo $vhost | cut -d' ' -f2`
 if [ "$vhostname" != "" ] && [ "$vhostip" != "" ] ; then
    vecho "    <Location /$vhostname/>"
    vecho "        ProxyPass http://$vhostip/"
    vecho "    </Location>"
 fi
done

# End the configuration with static stuff
vecho "</virtualHost>"

# Restart Apache
service httpd restart
