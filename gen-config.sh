#!/bin/sh

##################GLOBALS#################
STARTCTID=100
ENDCTID=310
DOMAIN="local"
TESTSUBDOMAIN="test"
ENV="test"   # Leave it blank for production
CONFIGPREFIX="vlabs.config"
PARALLEL="3"
IPPREFIX="10.4.13."
REPOUSER="svnadmin"
REPOHOST="svn.virtual-labs.ac.in"
BUILDDIR="~"
##########################################

###############DEFAULTS###################
OSTEMPLATE=centos-6.3-x86_64 # Default Template
NAMESERVER=10.4.12.157
DISKSPACE=1G
RAM=128M
HOSTNAME=labxxx
IPADD=10.10.10.10
PKGMGR="yum"   # Default Package Manager
SRVMGR="chkconfig"
DEFAULT="%"  # Indicator for taking default values
##########################################

###############OPENVZ COMMANDS############
VZCTL="vzctl"
VZDUMP="vzdump"
VZLIST="vzlist"
##########################################

##############VIRSH COMMANDS##############
VIRSH="virsh"
##########################################

vid_list=$(vzlist -H -a -o ctid -s ctid| sed 's/^[ \t]*//g')
vid_list_available=

ctid=$STARTCTID

for vid in $vid_list; 
do
 if [ "$ctid" == "$vid" ] ; then 
   echo $ctid >/dev/null
 else
   while [ "$ctid" != "$vid" ] ; do
    vid_list_available="$vid_list_available $ctid"
    ctid=`expr $ctid + 1`
   done
 fi
ctid=`expr $ctid + 1`
done

if [ "$ctid" != "$ENDCTID" ] ; then 
 while [ "$ctid" != "$ENDCTID" ] ; do
  vid_list_available="$vid_list_available $ctid"
  ctid=`expr $ctid + 1`
 done
fi

#echo $vid_list_available

# Delete older configs if exists
i=0
while [ "$i" \< "$PARALLEL" ] ; do
  if [ -f $CONFIGPREFIX.$i ]; then
     rm -rf $CONFIGPREFIX.$i
  fi
  i=`expr $i + 1`
done

vhost_list=$(vzlist -H -a -o hostname -s hostname| cut -d'.' -f1 | sed 's/^[ \t]*//g')

COUNT=0  # Total no of configs written
cat *_deps | sort -u | while read line;
 do
  modflag=`echo $line | cut -d' ' -f1`
  labid=`echo $line | cut -d' ' -f2`
  repotype=`echo $line | cut -d' ' -f3`
  reponame=`echo $line | cut -d' ' -f4` 
  ostemplate=`echo $line | cut -d' ' -f5`
  diskspace=`echo $line | cut -d' ' -f6`
  ram=`echo $line | cut -d' ' -f7`
  deps=`echo $line | cut -d' ' -f8-17 | sed 's/'$DEFAULT'//g'` 
  servs=`echo $line | cut -d' ' -f18-27 | sed 's/'$DEFAULT'//g'`

  # Ignore if header
  if [ "$labid" == "labid" ] ; then
   continue
  fi

  # Check for invalid data
  if [ "$labid" == "" ] || [ "$repotype" == "" ] || [ "$reponame" == "" ] ; then 
    echo "Invalid data found skipping...."
  fi
 
  #Set defaults for non-mandatory fields
  if [ "$ostemplate" == "" ] || [ "$ostemplate" == "$DEFAULT" ] ; then
    ostemplate=$OSTEMPLATE
  fi
  if [ "$diskspace" == "" ] || [ "$diskspace" == "$DEFAULT" ] ; then 
    diskspace=$DISKSPACE
  fi
  if [ "$ram" == "" ] || [ "$ram" == "$DEFAULT" ] ; then
    ram=$RAM
  fi

  # If Environment is test append test to the hostname 
  if [ "$ENV" != "" ]; then
    labid="$labid-$ENV"
  fi

  # Compare hosts and see what needs to be done
  vhost=$(echo $vhost_list | cut -d' ' -f1)

  # Choose config-file
  CONFIG=$CONFIGPREFIX.`expr $COUNT % $PARALLEL`

  while [ "$labid" \> "$vhost" ] && [ "$vhost" != "" ] ;
   do
        # Extra container running mark for deletion
        delctid=$($VZLIST -H -a -o ctid -h $vhost.$DOMAIN | sed 's/^[ \t]*//g')
        echo "########$vhost############" >> $CONFIG
        echo "$VZCTL stop $delctid" >> $CONFIG
#       echo "$VZCTL destroy $delctid" >> $CONFIG
        echo "" >> $CONFIG
        vhost_list=$(echo $vhost_list | cut -d' ' -f2-400)
        vhost=$(echo $vhost_list | cut -d' ' -f1)
        COUNT=`expr $COUNT + 1`
   done

  echo "########$labid############" >> $CONFIG
  if [ "$labid" == "$vhost" ]; then
     # Container and config both exist , just update config if modflag is set
   if [ "$modflag" == "1" ]; then 
     echo "$VZCTL set $ctid --diskspace $diskspace --ram $ram --nameserver $NAMESERVER --save" >> $CONFIG
     COUNT=`expr $COUNT + 1`
   fi
   vhost_list=$(echo $vhost_list | cut -d' ' -f2-400)
  else 
    # Newly added lab - mark for creation
    # Pick next available id from vid_list_available
    ctid=$(echo $vid_list_available | cut -d' ' -f1)  
    # Strip the ctid we used 
    vid_list_available=$(echo $vid_list_available | cut -d' ' -f2-400)
    echo "$VZCTL create $ctid --ostemplate $ostemplate --hostname $labid.$DOMAIN --ipadd $IPPREFIX$ctid --diskspace $diskspace" >> $CONFIG
    echo "$VZCTL start $ctid" >> $CONFIG
    echo "$VZCTL set $ctid --nameserver $NAMESERVER --ram $ram --save" >> $CONFIG
    COUNT=`expr $COUNT + 1`
  fi

  # Check OS Architecture and Install dependencies (1-10)
  OSARCH=$(echo $ostemplate | cut -d'-' -f1)
  case $OSARCH in 
    debian | ubuntu)
      PKGMGR="apt-get"
      PKGINSTALL="install"
      PKGREMOVE="remove"
      SRVMGR="update-rc.d"
      SRVADD=""
      SRVENABLE="enable"
      SRVDISABLE="disable"
      SRVREMOVE="remove"
      ;;
    centos | fedora | scientific | suse | *)
      PKGMGR="yum"
      PKGINSTALL="install"
      PKGREMOVE="remove"
      SRVMGR="chkconfig"
      SRVADD="--add"
      SRVENABLE="on"
      SRVDISABLE="off"
      SRVREMOVE="--del"
      ;;
  esac

  # Install Dependencies
  for dep in $deps ; 
  do
    echo "$VZCTL exec $ctid \"$PKGMGR $PKGINSTALL $dep\" " >> $CONFIG
  done 
 
  # Install and enable services 
  for serv in $servs ; 
  do
    echo "$VZCTL exec $ctid \"$SRVMGR $SRVADD $serv\" " >> $CONFIG
    echo "$VZCTL exec $ctid \"$SRVMGR $serv $SRVENABLE\" " >> $CONFIG
  done

  # Checkout the code
  # Assuming default is bzr repository
     BZREXTRA="/trunk"
     CREATEOPER="branch"
     UPDATEOPER="pull"
  if [ "$repotype" == "git" ] ; then
     BZREXTRA=""
     CREATEOPER="clone"
     UPDATEOPER="pull"
  fi
  if [ "$repotype" == "svn" ] ; then
     BZREXTRA=""
     CREATEOPER="checkout"
     UPDATEOPER="update"
  fi
  
  echo "$VZCTL exec $ctid \"$repotype $CREATEOPER $repotype+ssh://$REPOUSER@$REPOHOST/labs/$labid/$repotype/$reponame$BZREXTRA $BUILDDIR/$labid \" " >> $CONFIG 

  echo "" >> $CONFIG
done


# Mark remaining running hosts for deletion
# Strange bug here - vhost_list is not proper
for vhost in $vhost_list; do
   delctid=$($VZLIST -H -a -o ctid -h $vhost.$DOMAIN | sed 's/^[ \t]*//g')
   CONFIG=$CONFIGPREFIX.`expr $COUNT % $PARALLEL`
   echo "########$vhost############" >> $CONFIG
   echo "$VZCTL stop $delctid" >> $CONFIG
#   echo "$VZCTL destroy $delctid" >> $CONFIG
   echo "" >> $CONFIG
   vhost_list=$(echo $vhost_list | cut -d' ' -f2-400)
   COUNT=`expr $COUNT + 1`
done
