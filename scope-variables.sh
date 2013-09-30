#!/bin/sh

vhost_list=$(vzlist -a -o hostname -s hostname)

for j in $vhost_list; do
  echo $j
  vhost_list=$(echo $vhost_list | cut -d' ' -f2-100)
  echo $vhost_list
done

echo $vhost_list
