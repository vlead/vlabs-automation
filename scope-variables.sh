#!/bin/sh

i="test1 test2 test3 test4 test5"

for j in $i; do
  echo $j
  i=$(echo $i | cut -d' ' -f2-100)
  echo $i
done

echo $i
