#!/bin/bash
#
#
#
#
# Read the test configuration parameters
#
source test_params.cfg

#
# If using character driver messaging mechanism, need to load eventfd_link 
# kernel module.  This module is not a Linux standard module which is 
# necessary for the user space vhost current implementation (CUSE-based)
# to communicate to the guest
#
if [ $vhost = "cuse" ]; then
	if lsmod | grep -q eventfd_link; then
		echo "Not loading eventfd_link (already loaded)"
	else
		# if insmod $DPDK_DIR/lib/librte_vhost/eventfd_link/eventfd_link.ko; then
		if insmod /lib/modules/`uname -r`/extra/eventfd_link.ko; then
			echo "Loaded eventfd_link module"
		else
			echo "Failed to load eventfd_link module, exiting"
			exit 1
		fi
	fi
fi

echo $P_dataplane
echo $V_dataplane

FOUND=`grep "$dev1" /proc/net/dev`

if  [ -n "$FOUND"  ] ; then
    echo "$dev1 exists"
else
    echo "$dev1 does not exist"
    exit
fi

FOUND=`grep "$dev2" /proc/net/dev`

if  [ -n "$FOUND"  ] ; then
    echo "$dev2 exists"
else
    echo "$dev2 does not exist"
    exit
fi


#
# Completely remove old OVS configuration
#
echo "Removing preexiting OVS configuration, processes, and logs..."
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

if [[ "{\(PP\)}" != $network_topology ]]; then
    echo "Starting libvirtd service..."
    
    LIBVIRTD_STATUS=`systemctl status libvirtd | grep Active | awk '{print $3}'`
    
    if [ "\(running\)" != $LIBVIRTD_STATUS ]; then
        echo "LIBVIRTD_STATUS = $LIBVIRTD_STATUS"
        echo "Starting libvirtd service..."
        systemctl start libvirtd
    else
        echo "libvirtd service already running..."
    fi
fi

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
        ovs-vsctl set Open_vSwitch . other_config:n-dpdk-rxqs=$num_queues_per_port
        #$prefix/bin/ovs-vsctl set Interface dpdk0 options:n_rxq=$num_queues_per_port
        #$prefix/bin/ovs-vsctl set Interface dpdk1 options:n_rxq=$num_queues_per_port
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
        ovs-vsctl set Open_vSwitch . other_config:n-dpdk-rxqs=$num_queues_per_port
        # ovs-vsctl set Interface dpdk0 options:n_rxq=$num_queues_per_port
        # ovs-vsctl set Interface dpdk1 options:n_rxq=$num_queues_per_port
        # ovs-vsctl set Interface vhost-user1 options:n_rxq=$num_queues_per_port
        # ovs-vsctl set Interface vhost-user2 options:n_rxq=$num_queues_per_port
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
