#! /bin/sh

output=$1
output=${output:=`dmesg | tail -1`}
output=`echo $output | sed -e 's/.*: //'`


first=`echo $output | awk '{ print $5; }'`
second=`echo $output | awk '{print $11; }'`

library=`echo $second | sed -e 's/\[.*//'`
second=`echo $second | sed -e 's/.*\[//' -e 's/\+.*//'`

address=`echo $((0x$first - 0x$second))`
address=`echo "obase=16; $address" | bc`

echo "Segmentation fault in $library at: 0x$address."
