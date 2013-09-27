
vhost_list=$(vzlist -H -a -o hostname -s hostname| sed 's/^[ \t]*//g')

echo $vhost_list

for vhost in $vhost_list; do
   delctid=$(vzlist -H -a -o ctid -h $vhost | sed 's/^[ \t]*//g')
   echo "########$vhost############" 
   echo "$VZCTL stop $delctid"
   echo "$VZCTL destroy $delctid" 
   echo "" 
   vhost_list=$(echo $vhost_list | cut -d' ' -f2-400)
   echo $vhost_list
done

echo $vhost_list
