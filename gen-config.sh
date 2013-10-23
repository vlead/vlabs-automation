#!/bin/sh

##################GLOBALS#################
STARTCTID=50
ENDCTID=255
DOMAIN="local"
TESTSUBDOMAIN="test"
ENV="-test"   # Leave it blank for production
CONFIGPREFIX="vlabs-cmds.conf"
PARALLEL="3"
IPPREFIX="10.4.13."
REPOUSER="svnadmin"
REPOPASS="adminsvn"
REPOHOST="svn.virtual-labs.ac.in"
BUILDUSER="root"
BUILDDIR="~$BUILDUSER"
DEPLOYDIR="/var/www/html"
DEPLOYVERFILE="vlabs-version.txt"
DEPLOYHOSTALIAS="emcee.virtual-labs.ac.in"
RSAKEY="id_svnadmin_rsa"
SLEEPSECS="10"
SETPROXY="export http_proxy='http://proxy.iiit.ac.in:8080';"
##########################################

###############DEFAULTS###################
OSTEMPLATE=centos-6-x86_64 # Default Template
NAMESERVER=10.4.12.157
DISKSPACE=3G
RAM=256M
HOSTNAME=labxxx
IPADD=10.10.10.10
PKGMGR="yum"   # Default Package Manager
SRVMGR="chkconfig"
DEFAULT="%"  # Indicator for taking default values
##########################################

###############OPENVZ COMMANDS############
VZ="/vz"
VZPRIVATE="$VZ/private"
VZCTL="vzctl"
VZEXECCMD="exec"
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
    vid_list_available="$vid_list_available$ctid "
    ctid=`expr $ctid + 1`
   done
 fi
ctid=`expr $ctid + 1`
done

if [ "$ctid" -le "$ENDCTID" ] ; then 
 while [ "$ctid" != "$ENDCTID" ] ; do
  vid_list_available="$vid_list_available$ctid "
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
vhost_list="$vhost_list "  #Append a space

COUNT=0  # Total no of configs written
IFS=$'\n'
for line in $(cat *_deps | sort -u);
 do
  labid=`echo $line | cut -d' ' -f1`
  modflag=`echo $line | cut -d' ' -f2`
  labdisc=`echo $line | cut -d' ' -f3`
  repotype=`echo $line | cut -d' ' -f4`
  reponame=`echo $line | cut -d' ' -f5` 
  ostemplate=`echo $line | cut -d' ' -f6`
  diskspace=`echo $line | cut -d' ' -f7`
  ram=`echo $line | cut -d' ' -f8`
  deps=`echo $line | cut -d' ' -f9-18 | sed 's/'$DEFAULT'//g'` 
  servs=`echo $line | cut -d' ' -f19-28 | sed 's/'$DEFAULT'//g'`

  # Ignore if header or commented config
  if [ "$labid" == "labid" ] || [ "$labid" == "#*" ] ; then
   continue
  fi

  # Check for invalid data
  if [ "$labid" == "" ] ; then 
    echo "Invalid data found skipping...."
    continue
  fi
 
  #Set defaults for non-mandatory fields

  if [ "$repotype" == "" ] || [ "$repotype" == "$DEFAULT" ] ; then
    # Default repotype is bzr
    repotype="bzr"
  fi

  if [ "$reponame" == "" ] || [ "$reponame" == "$DEFAULT" ] ; then
    # Default reponame is labid 
    reponame="$labid"
  fi
 
  if [ "$ostemplate" == "" ] || [ "$ostemplate" == "$DEFAULT" ] ; then
    ostemplate=$OSTEMPLATE
  fi
  if [ "$diskspace" == "" ] || [ "$diskspace" == "$DEFAULT" ] ; then 
    diskspace=$DISKSPACE
  fi
  if [ "$ram" == "" ] || [ "$ram" == "$DEFAULT" ] ; then
    ram=$RAM
  fi

  # Construct the labhost by appending ENV to labid 
   labhost="$labid$ENV"

  # Compare hosts and see what needs to be done
  vhost=$(echo $vhost_list | cut -d' ' -f1)

  # Choose config-file
  CONFIG=$CONFIGPREFIX.`expr $COUNT % $PARALLEL`

  while [ "$labhost" \> "$vhost" ] && [ "$vhost" != "" ] ;
   do
        # Extra container running mark for deletion
        delctid=$($VZLIST -H -a -o ctid -h $vhost.$DOMAIN | sed 's/^[ \t]*//g')
        echo "########$vhost-start############" >> $CONFIG
	echo "echo \"###HOST=$vhost##CTID=$delctid###\"" >> $CONFIG
	echo "echo \"\`date\`\"" >> $CONFIG
        echo "$VZCTL stop $delctid" >> $CONFIG
#       echo "$VZCTL destroy $delctid" >> $CONFIG
	echo "########$vhost-end############" >> $CONFIG
        echo "" >> $CONFIG
        vhost_list=$(echo $vhost_list | cut -d' ' -f2-400)
        vhost=$(echo $vhost_list | cut -d' ' -f1)
        COUNT=`expr $COUNT + 1`
   done

  if [ "$labhost" == "$vhost" ]; then
     # Container and config both exist , just update config if modflag is set
   if [ "$modflag" == "1" ]; then 
     echo "########$labhost-start############" >> $CONFIG
     ctid=$($VZLIST -H -a -o ctid -h $vhost.$DOMAIN | sed 's/^[ \t]*//g')
     echo "echo \"###HOST=$labhost##CTID=$ctid###\"" >> $CONFIG
     echo "echo \"\`date\`\"" >> $CONFIG
     echo "$VZCTL set $ctid --diskspace $diskspace --ram $ram --nameserver $NAMESERVER --save" >> $CONFIG
     COUNT=`expr $COUNT + 1`
   fi
   vhost_list=$(echo $vhost_list | cut -d' ' -f2-400)
  else 

    ## Newly added lab - mark for creation
    # Pick next available id from vid_list_available
    ctid=$(echo $vid_list_available | cut -d' ' -f1)  
    # If no more VIDs are available echo an error message
    if [ "$ctid" == "" ] ; then 
      echo "Available VIDs and IPs Exhausted...Unable to create new VMs.."
      continue
    fi

    # Force modflag=1
    modflag=1
    echo "########$labhost-start############" >> $CONFIG
    echo "echo \"###HOST=$labhost##CTID=$ctid##IP=$IPPREFIX$ctid##OS=$ostemplate###\"" >> $CONFIG
    echo "echo \"\`date\`\"" >> $CONFIG
    # Strip the ctid we used 
    vid_list_available=$(echo $vid_list_available | cut -d' ' -f2-400)
    
    # Create commands for VM creation
    echo "$VZCTL create $ctid --ostemplate $ostemplate --hostname $labhost.$DOMAIN --ipadd $IPPREFIX$ctid --diskspace $diskspace" >> $CONFIG
    echo "$VZCTL start $ctid" >> $CONFIG
    echo "$VZCTL set $ctid --nameserver $NAMESERVER --ram $ram --save" >> $CONFIG
    # Disable strict host checking and add keys for $REPOHOST
    echo "$VZCTL $VZEXECCMD $ctid \"mkdir -p ~$BUILDUSER/.ssh\" " >> $CONFIG
    echo "$VZCTL $VZEXECCMD $ctid \"echo Host $REPOHOST $'\n'$'\t' StrictHostKeyChecking no $'\n'$'\t' IdentityFile ~$BUILDUSER/.ssh/$RSAKEY > ~$BUILDUSER/.ssh/config \" " >> $CONFIG 
    # Add the RSA Private key for logging on to SVN server
    echo "cat $RSAKEY | $VZCTL $VZEXECCMD $ctid \"cat - > ~$BUILDUSER/.ssh/$RSAKEY \" " >> $CONFIG
    echo "$VZCTL $VZEXECCMD $ctid \"chmod 600 ~$BUILDUSER/.ssh/$RSAKEY \" " >> $CONFIG
    COUNT=`expr $COUNT + 1`
  fi

  if [ "$modflag" == "1" ] ; then
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
	DEPLOYDIR="/var/www"
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
	DEPLOYDIR="/var/www/html"
        ;;
    esac

    # First sleep for 15 secs for previous changes to get affect
    echo "sleep $SLEEPSECS" >> $CONFIG

    ## Install Dependencies
    echo "$VZCTL $VZEXECCMD $ctid \"$SETPROXY $PKGMGR update -y\" " >> $CONFIG

    # Install/Configure {bzr,git,svn} on all by default
    echo "$VZCTL $VZEXECCMD  $ctid \"$SETPROXY $PKGMGR $PKGINSTALL bzr git subversion -y\" " >> $CONFIG

    # Install/Configure other packages as requested
    oldifs=$IFS
    IFS=' '
    if [ "$deps" != "" ] ; then
     for dep in $deps ; 
     do
       echo "$VZCTL $VZEXECCMD  $ctid \"$SETPROXY $PKGMGR $PKGINSTALL $dep -y\" " >> $CONFIG
     done
    fi 
 
    # Install and enable services 
    for serv in $servs ; 
    do
      echo "$VZCTL $VZEXECCMD $ctid \"$SRVMGR $SRVADD $serv\" " >> $CONFIG
      echo "$VZCTL $VZEXECCMD $ctid \"$SRVMGR $serv $SRVENABLE\" " >> $CONFIG
    done
    IFS=$oldifs

    # Checkout the code
    # Assuming default is bzr repository
       BZREXTRA="/trunk"
       OPER="branch"
    if [ "$repotype" == "git" ] ; then
       BZREXTRA=""
       OPER="clone"
    fi
    if [ "$repotype" == "svn" ] ; then
       BZREXTRA=""
       OPER="checkout"
    fi

    # Delete and check-out the repository
    echo "$VZCTL $VZEXECCMD $ctid \"rm -rf $BUILDDIR/$labid\" " >> $CONFIG 
    echo "$VZCTL $VZEXECCMD $ctid \"$repotype $OPER $repotype+ssh://$REPOUSER@$REPOHOST/labs/$labid/$repotype/$reponame$BZREXTRA $BUILDDIR/$labid\" " >> $CONFIG 

    # Run the make-file to build and deploy the lab
    echo "$VZCTL $VZEXECCMD $ctid \"cd $BUILDDIR/$labid/src; make\" " >> $CONFIG
    echo "$VZCTL $VZEXECCMD $ctid \"rm -rf $DEPLOYDIR/* \" " >> $CONFIG
    echo "$VZCTL $VZEXECCMD $ctid \"rsync -avz $BUILDDIR/$labid/build/ $DEPLOYDIR \" " >> $CONFIG
    echo "$VZCTL $VZEXECCMD $ctid \"echo \\\"**************************************************\\\" > $DEPLOYDIR/$DEPLOYVERFILE\" " >> $CONFIG
    echo "$VZCTL $VZEXECCMD $ctid \"echo $'\t'Deployed Date: \"\`date\`\"$'\n'$'\t'Labid: $labid$'\n'$'\t'Repotype: $repotype >> $DEPLOYDIR/$DEPLOYVERFILE\" " >> $CONFIG
    echo "$VZCTL $VZEXECCMD $ctid \"echo $'\t'LabDiscipline: $labdisc$'\n'$'\t'ContainerID: $ctid$'\n'$'\t'LocalIP: $IPPREFIX$ctid >> $DEPLOYDIR/$DEPLOYVERFILE\" " >> $CONFIG
    echo "$VZCTL $VZEXECCMD $ctid \"echo $'\t'Domain: $DOMAIN$'\n'$'\t'Environment: $ENV$'\n'$'\t'Modflag: $modflag >> $DEPLOYDIR/$DEPLOYVERFILE\" " >> $CONFIG
    echo "$VZCTL $VZEXECCMD $ctid \"echo $'\t'RepoName: $reponame$'\n'$'\t'OSTemplate: $ostemplate$'\n'$'\t'Diskspace: $diskspace >> $DEPLOYDIR/$DEPLOYVERFILE\" " >> $CONFIG
    echo "$VZCTL $VZEXECCMD $ctid \"echo $'\t'RAM: $ram$'\n'$'\t'Package Dependencies: $deps$'\n'$'\t'Services: $servs$'\n'$'\t'DeployLocation: $DEPLOYDIR >> $DEPLOYDIR/$DEPLOYVERFILE\" " >> $CONFIG

    # Simple Automatic testing
    # Echo a random text into the version file and then access it using wget and verify the content is same
    echo "randomtext=\`echo \"\\\`date\\\`\" | md5sum | sed 's/[ \t]*//g'\`" >> $CONFIG
    echo "$VZCTL $VZEXECCMD $ctid \"echo  $'\t'Randomtext: \"\$randomtext\" >> $DEPLOYDIR/$DEPLOYVERFILE\" " >> $CONFIG
    echo "wget --no-proxy $IPPREFIX$ctid/$DEPLOYVERFILE -O $DEPLOYVERFILE" >> $CONFIG
    echo "if [ \"\$randomtext\" == \"\`grep Randomtext $DEPLOYVERFILE | cut -d':' -f2 | sed 's/^[ \t]*//g'\`\" ] ; then \
    echo \"VTEST: Success\"; else echo \"VTEST: Failure\"; fi" >> $CONFIG
    echo "$VZCTL $VZEXECCMD $ctid \"echo \\\"**************************************************\\\" > $DEPLOYDIR/$DEPLOYVERFILE\" " >> $CONFIG

    # Indicate end of the lab config
    echo "########$labhost-end############" >> $CONFIG
    echo "" >> $CONFIG
  fi  # End of if loop for modflag

done # End of while loop

# Mark remaining running hosts for deletion
for vhost in $vhost_list; do
   delctid=$($VZLIST -H -a -o ctid -h $vhost.$DOMAIN | sed 's/^[ \t]*//g')
   CONFIG=$CONFIGPREFIX.`expr $COUNT % $PARALLEL`
   echo "########$vhost-start############" >> $CONFIG
   echo "echo \"###HOST=$vhost##CTID=$delctid###\"" >> $CONFIG
   echo "$VZCTL stop $delctid" >> $CONFIG
#   echo "$VZCTL destroy $delctid" >> $CONFIG
   echo "" >> $CONFIG
   vhost_list=$(echo $vhost_list | cut -d' ' -f2-400)
   COUNT=`expr $COUNT + 1`
   echo "########$vhost-end############" >> $CONFIG
done
