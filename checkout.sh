#!/bin/sh

USER=svnadmin
ROOTDIR=$PWD
DEPLOYDIR="/var/www/labs/"
DEPSFILE=iiith_deps

cat $DEPSFILE | while read line ;
do
  modflag=`echo $line | awk -F' ' '{print $1}'`
  labid=`echo $line | awk -F' ' '{print $2}'`
  repotype=`echo $line | awk -F' ' '{print $3}'`
  reponame=`echo $line | awk -F' ' '{print $4}'`

  echo $labid $repotype $reponame
  if [ $labid != "labid" ]; then   # Not header
 
###########CHECKOUT#################
   rm -rf $labid

   # Bazaar repository
   if [ $repotype == "bzr" ]; then
    bzr branch bzr+ssh://$USER@bzr.virtual-labs.ac.in/labs/$labid/bzr/$reponame/trunk $labid
   fi

   # Git repository

   # SVN repository
   if [ $repotype == "svn" ]; then
   svn co svn+ssh://svnadmin@svn.virtual-labs.ac.in/labs/$labid/svn/$reponame $labid
   fi
##########BUILD####################
#  cd $labid/src
#  make 
#  cd $ROOTDIR

##########DEPLOY###################
#  rsync -avz $labid/build/ /var/www/html/labs/$labid/

  fi
done
