#!/bin/bash

#
# Current OVS packet throughput testing comes in several different forms.  Test descriptions will include the 
# following nomenclature:
#
# Example 1:
#   {(PP)} ............. Bridge 1:  (port1 = 10Gbps, port2 = 10Gbps)
#
# Example 2:
#   {(PV),(VP)} ........ Bridge 1:  (port1 = 10Gb, port2 = virtio)
#                        Bridge 2:  (port3 = virtio, port4 = 10Gbps)
#
# Example 3:
#   {(PV),(VV)(VP)} .... Bridge1:  (port1 = 10Gbps, port2 = virtio)
#                        Bridge2:  (port3 = virtio, port4 = virtio)
#                        Bridge3:  (port5 = virtio, port6 = 10Gbps)
#
#
# Test Cases:
#
# I.    {(PP)} - Bridge 1:  (port1 = 10Gbps, port2 = 10Gbps)
#
#       P_dataplane = kernel
#       V_dataplane = N/A
#
#       UNIDIRECTIONAL PACKET PATH:
#           1.  Packets input physical device A and RX into OVS
#           2.  Packets forwarded via host machine virtual switch 'OVS + Linux kernel' bridging physical interfaces A and B
#           3.  Packets TX from OVS and out physical device B
#
#       Note:  BIDIRECTIONAL packet path includes the above and additionally packets traversed into physical device B,
#              through the DUT, and out device A (steps 3, 2, 1)
#
#
# II.   {(PP)} - Bridge 1:  (port1 = 10Gbps, port2 = 10Gbps)
#
#       P_dataplane = dpdk
#       V_dataplane = N/A
#
#       UNIDIRECTIONAL PACKET PATH:
#           1.  Packets input physical device A and RX into OVS
#           2.  Packets forwarded via host machine virtual switch 'OVS + dpdk' bridging physical interfaces A and B
#           3.  Packets TX from OVS and out physical device B
#
#       Note:  BIDIRECTIONAL packet path includes the above and additionally packets traversed into physical device B,
#              through the DUT, and out device A (steps 3, 2, 1)
#
#
# III.  {(PV),(VP)} - Bridge 1:  (port1 = 10Gbps, port2 = virtio)
#                     Bridge 2:  (port3 = virtio, port4 = 10Gbps)
#
#       P_dataplane = kernel
#       V_dataplane = kernel
#
#       UNIDIRECTIONAL PACKET PATH:
#           1.  Packets input physical device A and RX into OVS
#           2.  Packets forwarded via host machine virtual switch 'OVS + kernel' bridging one physical interface and one virtual interface
#           3.  Packets in virtual machine vm1 will be bridged amongst two virtual interfaces
#           4.  Packets TX to host machine virtual switch 'OVS + kernel' bridging one virtual interface and one physical interface
#           5.  Packets TX from OVS and out physical device B
#
#       Note:  BIDIRECTIONAL packet path includes the above and additionally packets traversed into physical device B,
#              through the DUT, and out device A (steps 5 through 1)
#
#
# IV.   {(PV),(VP)} - Bridge 1:  (port1 = 10Gbps, port2 = virtio)
#                     Bridge 2:  (port3 = virtio, port4 = 10Gbps)
#
#       P_dataplane = dpdk
#       V_dataplane = dpdk
#
#       UNIDIRECTIONAL PACKET PATH:
#           1.  Packets input physical device A and RX into OVS
#           2.  Packets forwarded via host machine virtual switch 'OVS + kernel' bridging one physical interface and one virtual interface
#           3.  Packets in virtual machine vm1 will be bridged amongst two virtual interfaces
#           4.  Packets TX to host machine virtual switch 'OVS + kernel' bridging one virtual interface and one physical interface
#           5.  Packets TX from OVS and out physical device B
#
#       Note:  BIDIRECTIONAL packet path includes the above and additionally packets traversed into physical device B,
#              through the DUT, and out device A (steps 5 through 1)
#
#
#
# V.   {(PV),(VV),(VP)} - Bridge 1:  (port1 = 10Gbps, port2 = virtio) 
#                         Bridge 2:  (port3 = virtio, port4 = virtio) 
#                         Bridge 3:  (port5 = virtio, port6 = 10Gbps)
#
#       P_dataplane = kernel
#       V_dataplane = kernel
#
#       UNIDIRECTIONAL PACKET PATH:
#
#       PACKET PATH:
#           1.  Packets in physical device A
#           2.  Packets forwarded via host machine virtual switch 'OVS + kernel' bridging one physical interface and one virtual interface
#           3.  Packets in virtual machine vm1 will be bridged amongst two virtual interfaces
#           4.  Packets TX to host machine virtual switch 'OVS + kernel' bridging one virtual interface and one physical interface
#           5.  Packets forwarded via host machine virtual switch 'OVS + kernel' bridging one physical interface and one virtual interface
#           6.  Packets in virtual machine vm2 will be bridged amongst two virtual interfaces
#           7.  Packets TX to host machine virtual switch 'OVS + kernel' bridging one virtual interface and one physical interface
#           8.  Packets TX from OVS and out physical device B
#
#       Note:  BIDIRECTIONAL packet path includes the above and additionally packets traversed into physical device B,
#              through the DUT, and out device A (steps 8 through 1)
#
#
# VI.  {(PV),(VP),(PV),(VP)} -Bridge 1:  (port1 = 10Gbps, port2 = virtio) 
#                             Bridge 2:  (port3 = virtio, port4 = 10Gbps) 
#                             Bridge 3:  (port5 = 10Gbps, port6 = virtio)
#                             Bridge 4:  (port7 = virtio, port8 = 10Gbps)
#
#       P_dataplane = dpdk
#       V_dataplane = dpdk
#
#       UNIDIRECTIONAL PACKET PATH:
#
#       PACKET PATH:
#           1.  Packets in physical device A
#           2.  Packets forwarded via host machine virtual switch 'OVS + kernel' bridging one physical interface and one virtual interface
#           3.  Packets in virtual machine vm1 will be bridged amongst two virtual interfaces
#           4.  Packets TX to host machine virtual switch 'OVS + kernel' bridging one virtual interface and one physical interface
#           5.  Packets forwarded via host machine virtual switch 'OVS + kernel' bridging one physical interface and one virtual interface
#           6.  Packets in virtual machine vm2 will be bridged amongst two virtual interfaces
#           7.  Packets TX to host machine virtual switch 'OVS + kernel' bridging one virtual interface and one physical interface
#           8.  Packets TX from OVS and out physical device B
#
#       Note:  BIDIRECTIONAL packet path includes the above and additionally packets traversed into physical device B,
#              through the DUT, and out device A (steps 8 through 1)
#

# Read the test configuration parameters
source test_params.cfg



echo $P_dataplane
echo $V_dataplane
exit 1

FOUND=`grep "$dev1" /proc/net/dev`

#if  [ -n "$FOUND"  ] ; then
    #echo "$dev1 exists"
#else
    #echo "$dev1 does not exist"
    #exit
#fi

FOUND=`grep "$dev2" /proc/net/dev`

# if  [ -n "$FOUND"  ] ; then
    # echo "$dev2 exists"
# else
    # echo "$dev2 does not exist"
    # exit
# fi


: <<'BILL_COMMENT0'
if [[ "dpdk" == $P_dataplane ]] && [[ "dpdk" == $V_dataplane ]]; then
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
    dpdk_nic_bind.py -u $bus_info_dev1 $bus_info_dev2
    sleep 1
    dpdk_nic_bind.py -b vfio-pci $bus_info_dev1 $bus_info_dev2
    sleep 1
    dpdk_nic_bind.py --status
fi
BILL_COMMENT0

#
# Completely remove old OVS configuration
#
killall ovs-vswitchd
killall ovsdb-server
killall ovsdb-server ovs-vswitchd
sleep 3
rm -rf $prefix/var/run/openvswitch/ovs-vswitchd.pid
rm -rf $prefix/var/run/openvswitch/ovsdb-server.pid
rm -rf $prefix/var/run/openvswitch/*
rm -rf $prefix/etc/openvswitch/*db*
rm -rf $prefix/var/log/openvswitch/*
modprobe -r openvswitch


#echo "Starting libvirtd service..."

#LIBVIRTD_STATUS=`service libvirtd status | grep Active | awk '{print $3}'`

#if [ "\(running\)" != $LIBVIRTD_STATUS ]; then
    #echo "LIBVIRTD_STATUS = $LIBVIRTD_STATUS"
    #echo "Starting libvirtd service..."
    #systemctl start libvirtd
#else
    #echo "libvirtd service already running..."
#fi
#exit 1;

echo "Configuring test network topology..."
#
# Process and execute test
#
case $network_topology in
"{(PP)}")
    if [[ "kernel" == $P_dataplane ]] && [[ "none" == $V_dataplane ]]; then
        echo "**********************************************************"
        echo "* Running {(P,P)} Test.  Bare metal"
        echo "* 'P' data plane is the kernel.  'V' data plane is none."
        echo "**********************************************************"

        message="{(PP)}: P_dataplane=kernel, V_dataplane=none"

        systemctl stop irqbalance
        #
        # start new ovs
        #
        modprobe openvswitch
        mkdir -p $prefix/var/run/openvswitch
        mkdir -p $prefix/etc/openvswitch
        $prefix/bin/ovsdb-tool create $prefix/etc/openvswitch/conf.db /usr/share/openvswitch/vswitch.ovsschema

        rm -rf /dev/usvhost-1
        $prefix/sbin/ovsdb-server -v --remote=punix:$DB_SOCK \
            --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
            --pidfile --detach || exit 1


        $prefix/bin/ovs-vsctl --no-wait init
        $prefix/sbin/ovs-vswitchd --pidfile --detach

        $prefix/bin/ovs-vsctl --if-exists del-br ovsbr0
        $prefix/bin/ovs-vsctl add-br ovsbr0
        $prefix/bin/ovs-vsctl add-port ovsbr0 $dev1
        $prefix/bin/ovs-vsctl add-port ovsbr0 $dev2
        $prefix/bin/ovs-ofctl del-flows ovsbr0
        #$prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=1,idle_timeout=0 actions=output:2"
        #$prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=2,idle_timeout=0 actions=output:1"
        
    elif [[ "dpdk" == $P_dataplane ]] && [[ "none" == $V_dataplane ]]; then

        systemctl stop irqbalance

        # start new ovs
        mkdir -p $prefix/var/run/openvswitch
        mkdir -p $prefix/etc/openvswitch
        $prefix/bin/ovsdb-tool create $prefix/etc/openvswitch/conf.db /usr/share/openvswitch/vswitch.ovsschema

        rm -rf /dev/usvhost-1
        $prefix/sbin/ovsdb-server -v --remote=punix:$DB_SOCK \
            --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
            --pidfile --detach || exit 1

        $prefix/sbin/ovs-vswitchd \
            --dpdk $cuse_dev_opt -c 0x1 \
            --socket-mem 1024,1024 \
            -- unix:$DB_SOCK \
            --pidfile \
            --log-file=$prefix/var/log/openvswitch/ovs-vswitchd.log 2>&1 >$prefix/var/log/openvswitch/ovs-launch.txt &

        $prefix/bin/ovs-vsctl --no-wait init
        
        echo "creating bridges"
        message="{(PP)}: P_dataplane=dpdk, V_dataplane=none"
        $prefix/bin/ovs-vsctl --if-exists del-br ovsbr0
        echo "creating ovsbr0 bridge"
        $prefix/bin/ovs-vsctl add-br ovsbr0 -- set bridge ovsbr0 datapath_type=netdev
        $prefix/bin/ovs-vsctl add-port ovsbr0 dpdk0 -- set Interface dpdk0 type=dpdk
        $prefix/bin/ovs-vsctl add-port ovsbr0 dpdk1 -- set Interface dpdk1 type=dpdk
        $prefix/bin/ovs-ofctl del-flows ovsbr0
        $prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=1,idle_timeout=0 actions=output:2"
        $prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=2,idle_timeout=0 actions=output:1"

        $prefix/bin/ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=$cpumask
#        $prefix/bin/ovs-vsctl set Interface dpdk0 options:n_rxq=$num_queues_per_port
#        $prefix/bin/ovs-vsctl set Interface dpdk1 options:n_rxq=$num_queues_per_port
        ovs-vsctl set Open_vSwitch . other_config:n-dpdk-rxqs=$num_queues_per_port

    else
        message="You big dummy"
    fi
    ;;
"{(PV),(VP)}")
    if [[ "kernel" == $P_dataplane ]] && [[ "kernel" == $V_dataplane ]]; then
        message="{(PV),(VP)}: P_dataplane=kernel, V_dataplane=kernel"

        systemctl stop irqbalance

        #
        # start new ovs
        #
        modprobe openvswitch
        mkdir -p $prefix/var/run/openvswitch
        mkdir -p $prefix/etc/openvswitch
        $prefix/bin/ovsdb-tool create $prefix/etc/openvswitch/conf.db /usr/share/openvswitch/vswitch.ovsschema

        rm -rf /dev/usvhost-1
        $prefix/sbin/ovsdb-server -v --remote=punix:$DB_SOCK \
            --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
            --pidfile --detach || exit 1

        $prefix/bin/ovs-vsctl --no-wait init
        $prefix/sbin/ovs-vswitchd --pidfile --detach

        # create the bridges/ports with 1 phys dev and 1 virt dev per bridge, to be used for 1 VM to forward packets
        $prefix/bin/ovs-vsctl --if-exists del-br ovsbr0
        $prefix/bin/ovs-vsctl add-br ovsbr0
        $prefix/bin/ovs-vsctl add-port ovsbr0 $dev1
        #$prefix/bin/ovs-vsctl add-port ovsbr0 vhost-user1
        $prefix/bin/ovs-ofctl del-flows ovsbr0
        #$prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=1,idle_timeout=0 actions=output:2"
        #$prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=2,idle_timeout=0 actions=output:1"

        $prefix/bin/ovs-vsctl --if-exists del-br ovsbr1
        $prefix/bin/ovs-vsctl add-br ovsbr1
        $prefix/bin/ovs-vsctl add-port ovsbr1 $dev2
        #$prefix/bin/ovs-vsctl add-port ovsbr1 vhost-user2
        $prefix/bin/ovs-ofctl del-flows ovsbr1
        #$prefix/bin/ovs-ofctl add-flow ovsbr1 "in_port=1,idle_timeout=0 actions=output:2"
        #$prefix/bin/ovs-ofctl add-flow ovsbr1 "in_port=2,idle_timeout=0 actions=output:1"
    else
        systemctl stop irqbalance

        mkdir -p $prefix/var/run/openvswitch
        mkdir -p $prefix/etc/openvswitch
        $prefix/bin/ovsdb-tool create $prefix/etc/openvswitch/conf.db /usr/share/openvswitch/vswitch.ovsschema

        rm -rf /dev/usvhost-1
        $prefix/sbin/ovsdb-server -v --remote=punix:$DB_SOCK \
            --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
            --pidfile --detach || exit 1


        screen -dmS ovs \
        sudo su -g qemu -c "umask 002; $prefix/sbin/ovs-vswitchd \
                    --dpdk $cuse_dev_opt -c 0x1 -n 3 \
                    --socket-mem 1024,1024 \
                    -- unix:$DB_SOCK \
                    --pidfile \
                    --log-file=$prefix/var/log/openvswitch/ovs-vswitchd.log 2>&1 >$prefix/var/log/openvswitch/ovs-launch.txt" 

        $prefix/bin/ovs-vsctl --no-wait init


        echo "creating bridges"
        message="{(PV),(VP)}: P_dataplane=dpdk, V_dataplane=dpdk"

        # create the bridges/ports with 1 phys dev and 1 virt dev per bridge, to be used for 1 VM to forward packets
        $prefix/bin/ovs-vsctl --if-exists del-br ovsbr0
        echo "creating ovsbr0 bridge"
        $prefix/bin/ovs-vsctl add-br ovsbr0 -- set bridge ovsbr0 datapath_type=netdev
        $prefix/bin/ovs-vsctl add-port ovsbr0 dpdk0 -- set Interface dpdk0 type=dpdk
        $prefix/bin/ovs-vsctl add-port ovsbr0 vhost-user1 -- set Interface vhost-user1 type=dpdkvhostuser
        $prefix/bin/ovs-ofctl del-flows ovsbr0
        $prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=1,idle_timeout=0 actions=output:2"
        $prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=2,idle_timeout=0 actions=output:1"
        
        $prefix/bin/ovs-vsctl --if-exists del-br ovsbr1
        echo "creating ovsbr1 bridge"
        $prefix/bin/ovs-vsctl add-br ovsbr1 -- set bridge ovsbr1 datapath_type=netdev
        $prefix/bin/ovs-vsctl add-port ovsbr1 vhost-user2 -- set Interface vhost-user2 type=dpdkvhostuser
        $prefix/bin/ovs-vsctl add-port ovsbr1 dpdk1 -- set Interface dpdk1 type=dpdk
        $prefix/bin/ovs-ofctl del-flows ovsbr1
        $prefix/bin/ovs-ofctl add-flow ovsbr1 "in_port=1,idle_timeout=0 actions=output:2"
        $prefix/bin/ovs-ofctl add-flow ovsbr1 "in_port=2,idle_timeout=0 actions=output:1"

        ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=$cpumask
        ovs-vsctl set Interface dpdk0 options:n_rxq=$num_queues_per_port
        ovs-vsctl set Interface dpdk1 options:n_rxq=$num_queues_per_port
        ovs-vsctl set Interface vhost-user1 options:n_rxq=$num_queues_per_port
        ovs-vsctl set Interface vhost-user2 options:n_rxq=$num_queues_per_port

: <<'BILL_COMMENT'
        cpumask=""
        for i in `seq 1 $num_queues_per_port`; do
            cpumask="55$cpumask"
        done
        ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=$cpumask
        ovs-vsctl set Interface dpdk0 options:n_rxq=$num_queues_per_port
        ovs-vsctl set Interface dpdk1 options:n_rxq=$num_queues_per_port
        ovs-vsctl set Interface vhost-user1 options:n_rxq=$num_queues_per_port
        ovs-vsctl set Interface vhost-user2 options:n_rxq=$num_queues_per_port
BILL_COMMENT
    fi
    ;;
"{(PV),(VV),(VP)}")
    systemctl stop irqbalance
    # start new ovs
    mkdir -p $prefix/var/run/openvswitch
    mkdir -p $prefix/etc/openvswitch
    $prefix/bin/ovsdb-tool create $prefix/etc/openvswitch/conf.db /usr/share/openvswitch/vswitch.ovsschema
    
    rm -rf /dev/usvhost-1
    $prefix/sbin/ovsdb-server -v --remote=punix:$DB_SOCK \
        --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
        --pidfile --detach || exit 1
    

    if [[ "kernel" == $P_dataplane ]] && [[ "kernel" == $V_dataplane ]]; then
        message="{(PV),(VV),(VP)}: P_dataplane=kernel, V_dataplane=kernel"
        
        #
        # start new ovs
        #
        modprobe openvswitch
        
        $prefix/bin/ovs-vsctl --no-wait init
        $prefix/sbin/ovs-vswitchd --pidfile --detach
        
        # create the bridges/ports with 1 phys dev and 1 virt dev per bridge, to be used for 1 VM to forward packets
        $prefix/bin/ovs-vsctl --if-exists del-br ovsbr0
        $prefix/bin/ovs-vsctl add-br ovsbr0
        $prefix/bin/ovs-vsctl add-port ovsbr0 $dev1
        $prefix/bin/ovs-vsctl add-port ovsbr0 vhost-user1
        $prefix/bin/ovs-ofctl del-flows ovsbr0
        #$prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=1,idle_timeout=0 actions=output:2"
        #$prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=2,idle_timeout=0 actions=output:1"
        
        $prefix/bin/ovs-vsctl --if-exists del-br ovsbr1
        $prefix/bin/ovs-vsctl add-br ovsbr1
        #$prefix/bin/ovs-vsctl add-port ovsbr1 $dev2
        $prefix/bin/ovs-vsctl add-port ovsbr1 vhost-user2
        $prefix/bin/ovs-vsctl add-port ovsbr1 vhost-user3
        $prefix/bin/ovs-ofctl del-flows ovsbr1
        #$prefix/bin/ovs-ofctl add-flow ovsbr1 "in_port=1,idle_timeout=0 actions=output:2"
        #$prefix/bin/ovs-ofctl add-flow ovsbr1 "in_port=2,idle_timeout=0 actions=output:1"
        
        
        
        # create the bridges/ports with 1 phys dev and 1 virt dev per bridge, to be used for 1 VM to forward packets
        $prefix/bin/ovs-vsctl --if-exists del-br ovsbr2
        $prefix/bin/ovs-vsctl add-br ovsbr2
        $prefix/bin/ovs-vsctl add-port ovsbr2 $dev2
        $prefix/bin/ovs-vsctl add-port ovsbr2 vhost-user4
        $prefix/bin/ovs-ofctl del-flows ovsbr2
        #$prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=1,idle_timeout=0 actions=output:2"
        #$prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=2,idle_timeout=0 actions=output:1"
        
    elif [[ "dpdk" == $P_dataplane ]] && [[ "dpdk" == $V_dataplane ]]; then
        systemctl stop irqbalance

        screen -dmS ovs \
        sudo su -g qemu -c "umask 002; $prefix/sbin/ovs-vswitchd \
                    --dpdk $cuse_dev_opt -c 0x1 -n 3 \
                    --socket-mem 1024,1024 \
                    -- unix:$DB_SOCK \
                    --pidfile \
                    --log-file=$prefix/var/log/openvswitch/ovs-vswitchd.log 2>&1 >$prefix/var/log/openvswitch/ovs-launch.txt" 

        $prefix/bin/ovs-vsctl --no-wait init
        
        echo "creating bridges"
        message="{(PV),(VV),(VP)}: P_dataplane=dpdk, V_dataplane=dpdk"
        # create the bridges/ports with 1 phys dev and 1 virt dev per bridge, to be used for 1 VM to forward packets
        $prefix/bin/ovs-vsctl --if-exists del-br ovsbr0
        echo "creating ovsbr0 bridge"
        $prefix/bin/ovs-vsctl add-br ovsbr0 -- set bridge ovsbr0 datapath_type=netdev
        $prefix/bin/ovs-vsctl add-port ovsbr0 dpdk0 -- set Interface dpdk0 type=dpdk
        $prefix/bin/ovs-vsctl add-port ovsbr0 vhost-user1 -- set Interface vhost-user1 type=dpdkvhostuser
        $prefix/bin/ovs-ofctl del-flows ovsbr0
        #$prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=1,idle_timeout=0 actions=output:2"
        #$prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=2,idle_timeout=0 actions=output:1"
        
        $prefix/bin/ovs-vsctl --if-exists del-br ovsbr1
        echo "creating ovsbr1 bridge"
        $prefix/bin/ovs-vsctl add-br ovsbr1 -- set bridge ovsbr1 datapath_type=netdev
        $prefix/bin/ovs-vsctl add-port ovsbr1 vhost-user2 -- set Interface vhost-user2 type=dpdkvhostuser
        $prefix/bin/ovs-vsctl add-port ovsbr1 vhost-user3 -- set Interface vhost-user3 type=dpdkvhostuser
        $prefix/bin/ovs-ofctl del-flows ovsbr1
        #$prefix/bin/ovs-ofctl add-flow ovsbr1 "in_port=1,idle_timeout=0 actions=output:2"
        #$prefix/bin/ovs-ofctl add-flow ovsbr1 "in_port=2,idle_timeout=0 actions=output:1"
        
        $prefix/bin/ovs-vsctl --if-exists del-br ovsbr2
        echo "creating ovsbr2 bridge"
        $prefix/bin/ovs-vsctl add-br ovsbr2 -- set bridge ovsbr2 datapath_type=netdev
        $prefix/bin/ovs-vsctl add-port ovsbr2 dpdk1 -- set Interface dpdk1 type=dpdk
        $prefix/bin/ovs-vsctl add-port ovsbr2 vhost-user4 -- set Interface vhost-user4 type=dpdkvhostuser
        $prefix/bin/ovs-ofctl del-flows ovsbr2
        #$prefix/bin/ovs-ofctl add-flow ovsbr1 "in_port=1,idle_timeout=0 actions=output:2"
        #$prefix/bin/ovs-ofctl add-flow ovsbr1 "in_port=2,idle_timeout=0 actions=output:1"
    else
        message="{(PV),(VV),(VP)}"
    fi
    ;;
*)
    message="A total loser"
    ;;
esac

echo $message

exit
