#!/bin/sh

USER=svnadmin
PASSWD=adminsvn
ROOTDIR=$PWD
DEPLOYDIR="/var/www/labs/"
DEPSFILE=iiith_deps
BUILDDIR=./labs
REPOHOST="svn.virtual-labs.ac.in"

cat $DEPSFILE | while read line ;
do
  modflag=`echo $line | awk -F' ' '{print $2}'`
  labid=`echo $line | awk -F' ' '{print $1}'`
  repotype=`echo $line | awk -F' ' '{print $3}'`
  reponame=`echo $line | awk -F' ' '{print $4}'`

  echo $labid $repotype $reponame
  if [ $labid != "labid" ]; then   # Not header
 
###########CHECKOUT#################
   rm -rf $labid

   # Bazaar repository
   if [ $repotype == "bzr" ]; then
    bzr branch bzr+ssh://$USER:$PASSWD@$REPOHOST/labs/$labid/bzr/$reponame/trunk $BUILDDIR/$labid
   fi

   # Git repository
   if [ $repotype == "git" ]; then
    git clone git+ssh://$USER:$PASSWD@$REPOHOST/labs/$labid/git/$reponame $BUILDDIR/$labid
   fi

   # SVN repository
   if [ $repotype == "svn" ]; then
   svn co svn+ssh://$USER@$REPOHOST/labs/$labid/svn/$reponame $BUILDDIR/$labid --password $PASSWD
   fi
##########BUILD####################
#  cd $labid/src
#  make 
#  cd $ROOTDIR

##########DEPLOY###################
#  rsync -avz $labid/build/ /var/www/html/labs/$labid/

  fi
done
