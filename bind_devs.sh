#!/bin/bash


#prefix="/usr/local" # used with locally built src
#prefix=""  # used with RPMs
prefix="/root/perf84/dpdk1607/dpdk-16.07/tools"

#dev1=em1
#dev2=em2
dev1=p2p1
dev2=p2p2


echo "Binding devices $dev1 and $dev2 to vfio-pci/DPDK"
bus_info_dev1=`ethtool -i $dev1 | grep 'bus-info' | awk '{print $2}'`
bus_info_dev2=`ethtool -i $dev2 | grep 'bus-info' | awk '{print $2}'`

echo $bus_info_dev1
echo $bus_info_dev2

modprobe vfio
modprobe vfio_pci

ifconfig $dev1 down
ifconfig $dev2 down
sleep 1
$prefix/dpdk-devbind.py -u $bus_info_dev1 $bus_info_dev2
sleep 1
$prefix/dpdk-devbind.py -b vfio-pci $bus_info_dev1 $bus_info_dev2
sleep 1
$prefix/dpdk-devbind.py --status
