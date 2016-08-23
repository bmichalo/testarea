#!/bin/bash

if [ $# -ne 3  ]; then
    echo -e "\n\n"
    echo -e "set_if_queues <interface_1> <interface_2> <number_of_combined_rxtx_channels>\n"
    exit 1
fi

FOUND_IFACE=`grep $1 /proc/net/dev`

if [ -n "$FOUND_IFACE" ]; then
    echo -e "Found network device $1\n"
else
    echo -e "\n"
    echo -e "Interface $1 does not exist\n"
    exit 1
fi

FOUND_IFACE=`grep $2 /proc/net/dev`

if [ -n "$FOUND_IFACE" ]; then
    echo -e "Found network device $2\n"
else
    echo -e "\n"
    echo -e "Interface $2 does not exist\n"
    exit 1
fi


if [[ $3 =~ ^[0-9]+$ && $3 -ge 1 && $3 -le 4 ]]; then
    echo -e "Combined channel number $3 is being set upon network devices $1 and $2..."
else
    echo -e "Bad combined channel number.  Must be a value 1, 2, 3, 4"
    exit 1
fi

ifconfig $1 down
ifconfig $2 down
sleep 1
ethtool -L $1 combined $3 
ethtool -L $2 combined $3 
sleep 1
ifconfig $1 up 
ifconfig $2 up 
sleep 1

if [ $3 -eq 1 ]; then
    echo "Setting $1-TxRx on CPU core 1"
    echo "Setting $2-TxRx on CPU core 3"
    tuna -q $1-TxRx* --cpus=1 -m -x
    tuna -q $2-TxRx* --cpus=3 -m -x
elif [ $3 -eq 2 ]; then
    echo "Setting $1-TxRx on CPU cores 1, 3"
    echo "Setting $2-TxRx on CPU cores 5, 7"
    tuna -q $1-TxRx* --cpus=1,3 -m -x
    tuna -q $2-TxRx* --cpus=5,7 -m -x
elif [ $3 -eq 3 ]; then
    echo "Setting $1-TxRx on CPU cores 1, 3, 5"
    echo "Setting $2-TxRx on CPU cores 7, 9, 11"
    tuna -q $1-TxRx* --cpus=1,3,5 -m -x
    tuna -q $2-TxRx* --cpus=7,9,11 -m -x
else
    echo "Setting $1-TxRx on CPU cores 1, 3, 5, 7"
    echo "Setting $2-TxRx on CPU cores 9, 11, 13, 15"
    tuna -q $1-TxRx* --cpus=1,3,5,7 -m -x
    tuna -q $2-TxRx* --cpus=9,11,13,15 -m -x
fi

echo -e "Setting $3 combined rxtx channels upon $1 and $2 successfully completed\n"
