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


DPDK_BOUND_TO_IFACES=`$dpdk_tools_path/dpdk-devbind.py --status | grep -A 2 "Network devices using DPDK-compatible driver" | grep none`

if [[ "dpdk" == $P_dataplane ]] && [[ "1" == $bind_ifs ]]; then
    if [[ "\<none\>" != $DPDK_BOUND_TO_IFACES ]]; then
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
        
    	echo "Binding devices $dev1 and $dev2 to vfio-pci/DPDK"
    	bus_info_dev1=`ethtool -i $dev1 | grep 'bus-info' | awk '{print $2}'`
    	bus_info_dev2=`ethtool -i $dev2 | grep 'bus-info' | awk '{print $2}'`
    	bus_info_dev3=`ethtool -i $dev3 | grep 'bus-info' | awk '{print $2}'`
    	bus_info_dev4=`ethtool -i $dev4 | grep 'bus-info' | awk '{print $2}'`
    	
    	echo $bus_info_dev1
    	echo $bus_info_dev2
    	echo $bus_info_dev3
    	echo $bus_info_dev4
    	
    	modprobe vfio
    	modprobe vfio_pci
    	
    	ifconfig $dev1 down
    	ifconfig $dev2 down
    	ifconfig $dev3 down
    	ifconfig $dev4 down
    	sleep 1
    	dpdk-devbind.py -u $bus_info_dev1 $bus_info_dev2 $bus_info_dev3 $bus_info_dev4
    	sleep 1
    	dpdk-devbind.py -b vfio-pci $bus_info_dev1 $bus_info_dev2 $bus_info_dev3 $bus_info_dev4
    	sleep 1
        echo "******************************"
        echo "* Newly bound interfaces:    *"
        echo "******************************"
    	dpdk-devbind.py --status
    fi
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

#
# OVS Identification
#
$prefix/bin/ovs-vsctl -V
$prefix/bin/ovs-ofctl -V

if [[ "{\(PP\)}" != $network_topology ]]; then
    
    LIBVIRTD_STATUS=`systemctl status libvirtd | grep Active | awk '{print $3}'`
    
    if [ "\(running\)" != $LIBVIRTD_STATUS ]; then
        echo "LIBVIRTD_STATUS = $LIBVIRTD_STATUS"
        echo "Starting libvirtd service..."
        systemctl start libvirtd
    else
        echo "libvirtd service already running..."
    fi
fi

systemctl stop irqbalance

echo "Configuring test network topology..."
#
# Process and execute test
#
case $network_topology in
"{(PP)}")
    if [[ "kernel" == $P_dataplane ]] && [[ "none" == $V_dataplane ]]; then
        echo "**********************************************************"
        echo "* Running {(P,P)} Test.  Bare metal"
        echo "* Physical Data Plane .... kernel"
        echo "* Virtual Data Plane ..... none"
        echo "**********************************************************"

        #
        # start new ovs
        #
        modprobe openvswitch
        mkdir -p $prefix/var/run/openvswitch
        mkdir -p $prefix/etc/openvswitch
        if [ $ovs_version == "2pt6" ]; then
            $prefix/bin/ovsdb-tool create $prefix/etc/openvswitch/conf.db /usr/local/share/openvswitch/vswitch.ovsschema
        else
            $prefix/bin/ovsdb-tool create $prefix/etc/openvswitch/conf.db /usr/share/openvswitch/vswitch.ovsschema
        fi

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
        echo "**********************************************************"
        echo "* Running {(P,P)} Test.  Bare metal"
        echo "* Physical Data Plane .... DPDK"
        echo "* Virtual Data Plane ..... none"
        echo "**********************************************************"

        # start new ovs
        mkdir -p $prefix/var/run/openvswitch
        mkdir -p $prefix/etc/openvswitch
        if [ $ovs_version == "2pt6" ]; then
            $prefix/bin/ovsdb-tool create $prefix/etc/openvswitch/conf.db /usr/local/share/openvswitch/vswitch.ovsschema
        else
            $prefix/bin/ovsdb-tool create $prefix/etc/openvswitch/conf.db /usr/share/openvswitch/vswitch.ovsschema
        fi

        rm -rf /dev/usvhost-1
        $prefix/sbin/ovsdb-server -v --remote=punix:$DB_SOCK \
            --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
            --pidfile --detach || exit 1

        echo "Starting vswitchd"
        if [ $ovs_version == "2pt6" ]; then
            $prefix/bin/ovs-vsctl --no-wait init 
            $prefix/bin/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
            $prefix/bin/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="1024,1024"
            $prefix/sbin/ovs-vswitchd \
                -c 0x1 \
                -- unix:$DB_SOCK \
                --pidfile \
                --log-file=$prefix/var/log/openvswitch/ovs-vswitchd.log 2>&1 >$prefix/var/log/openvswitch/ovs-launch.txt &
        
            $prefix/sbin/ovs-vswitchd unix:$DB_SOCK --pidfile --detach
        else
            $prefix/sbin/ovs-vswitchd \
                --dpdk $cuse_dev_opt -c 0x1 \
                --socket-mem 1024,1024 \
                -- unix:$DB_SOCK \
                --pidfile \
                --log-file=$prefix/var/log/openvswitch/ovs-vswitchd.log 2>&1 >$prefix/var/log/openvswitch/ovs-launch.txt &
        
            $prefix/bin/ovs-vsctl --no-wait init 
        fi
        echo "Started vswitchd ***************"


        
        echo "creating bridges"
        $prefix/bin/ovs-vsctl --if-exists del-br ovsbr0
        echo "creating ovsbr0 bridge"
        $prefix/bin/ovs-vsctl add-br ovsbr0 -- set bridge ovsbr0 datapath_type=netdev
        $prefix/bin/ovs-vsctl add-port ovsbr0 dpdk0 -- set Interface dpdk0 type=dpdk
        $prefix/bin/ovs-vsctl add-port ovsbr0 dpdk1 -- set Interface dpdk1 type=dpdk
        $prefix/bin/ovs-ofctl del-flows ovsbr0
        $prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=1,idle_timeout=0 actions=output:2"
        $prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=2,idle_timeout=0 actions=output:1"

        if [ $ovs_version == "2pt6" ]; then
            $prefix/bin/ovs-vsctl set Interface dpdk0 options:n_rxq=$num_queues_per_port
            $prefix/bin/ovs-vsctl set Interface dpdk1 options:n_rxq=$num_queues_per_port
        else
            $prefix/bin/ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=$cpumask
            $prefix/bin/ovs-vsctl set Open_vSwitch . other_config:n-dpdk-rxqs=$num_queues_per_port
        fi
    else
        echo "{(P,P)} fatal error.  Either P_dataplane or V_dataplane is not understood"
    fi
    ;;
"{(VV)}")
    if [[ "none" == $P_dataplane ]] && [[ "dpdk" == $V_dataplane ]]; then
        echo "**********************************************************"
        echo "* Running {(V,V)} Test."
        echo "* Physical Data Plane .... none"
        echo "* Virtual Data Plane ..... DPDK"
        echo "**********************************************************"
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


        echo "creating bridge"

        # create the bridges/ports with 1 phys dev and 1 virt dev per bridge, to be used for 1 VM to forward packets
        $prefix/bin/ovs-vsctl --if-exists del-br ovsbr0
        echo "creating ovsbr0 bridge"
        $prefix/bin/ovs-vsctl add-br ovsbr0 -- set bridge ovsbr0 datapath_type=netdev
        $prefix/bin/ovs-vsctl add-port ovsbr0 vhost-user1 -- set Interface vhost-user1 type=dpdkvhostuser
        $prefix/bin/ovs-vsctl add-port ovsbr0 vhost-user2 -- set Interface vhost-user2 type=dpdkvhostuser
        $prefix/bin/ovs-ofctl del-flows ovsbr0
        $prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=1,idle_timeout=0 actions=output:2"
        $prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=2,idle_timeout=0 actions=output:1"
        
        $prefix/bin/ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=$cpumask
        #$prefix/bin/ovs-vsctl set Open_vSwitch . other_config:n-dpdk-rxqs=$num_queues_per_port
        # ovs-vsctl set Interface dpdk0 options:n_rxq=$num_queues_per_port
        # ovs-vsctl set Interface dpdk1 options:n_rxq=$num_queues_per_port
        $prefix/bin/ovs-vsctl set Interface vhost-user1 options:n_rxq=$num_queues_per_port
        $prefix/bin/ovs-vsctl set Interface vhost-user2 options:n_rxq=$num_queues_per_port

    elif [[ "none" == $P_dataplane ]] && [[ "kernel" == $V_dataplane ]]; then
        echo "**********************************************************"
        echo "* Running {(V,V)} Test."
        echo "* Physical Data Plane .... none"
        echo "* Virtual Data Plane ..... kernel"
        echo "**********************************************************"

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
        #$prefix/bin/ovs-vsctl add-port ovsbr0 $dev1
        #$prefix/bin/ovs-vsctl add-port ovsbr0 $dev2
        $prefix/bin/ovs-ofctl del-flows ovsbr0
        #$prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=1,idle_timeout=0 actions=output:2"
        #$prefix/bin/ovs-ofctl add-flow ovsbr0 "in_port=2,idle_timeout=0 actions=output:1"

    else
        echo "Bad attempt to create bridge with vhostuser interfaces"
    fi
    ;;
"{(PV),(VP)}")
    if [[ "kernel" == $P_dataplane ]] && [[ "kernel" == $V_dataplane ]]; then
        echo "**********************************************************"
        echo "* Running {(P,V), (V,P)} Test."
        echo "* Physical Data Plane .... kernel"
        echo "* Virtual Data Plane ..... kernel"
        echo "**********************************************************"

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


        screen -dmS ovs \
        sudo su -g qemu -c "umask 002; $prefix/sbin/ovs-vswitchd \
                 --dpdk $cuse_dev_opt -c 0x1 -n 3 \
                 --socket-mem 1024,1024 \
                 -- unix:$DB_SOCK \
                 --pidfile \
                 --log-file=$prefix/var/log/openvswitch/ovs-vswitchd.log 2>&1 >$prefix/var/log/openvswitch/ovs-launch.txt" 

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
        echo "**********************************************************"
        echo "* Running {(P,V), (V,P)} Test."
        echo "* Physical Data Plane .... DPDK"
        echo "* Virtual Data Plane ..... DPDK"
        echo "**********************************************************"


        # start new ovs
        mkdir -p $prefix/var/run/openvswitch
        mkdir -p $prefix/etc/openvswitch
        if [ $ovs_version == "2pt6" ]; then
            $prefix/bin/ovsdb-tool create $prefix/etc/openvswitch/conf.db /usr/local/share/openvswitch/vswitch.ovsschema
        else
            $prefix/bin/ovsdb-tool create $prefix/etc/openvswitch/conf.db /usr/share/openvswitch/vswitch.ovsschema
        fi

        rm -rf /dev/usvhost-1
        $prefix/sbin/ovsdb-server -v --remote=punix:$DB_SOCK \
            --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
            --pidfile --detach || exit 1

        if [ $ovs_version == "2pt6" ]; then
            $prefix/bin/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
            $prefix/bin/ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="1024,1024"
            screen -dmS ovs \
            sudo su -g qemu -c "umask 002; $prefix/sbin/ovs-vswitchd \
                unix:$DB_SOCK \
                --pidfile \
                --log-file=$prefix/var/log/openvswitch/ovs-vswitchd.log 2>&1 >$prefix/var/log/openvswitch/ovs-launch.txt"

        else
            screen -dmS ovs \
            sudo su -g qemu -c "umask 002; $prefix/sbin/ovs-vswitchd \
                        --dpdk $cuse_dev_opt -c 0x1 -n 3 \
                        --socket-mem 1024,1024 \
                        -- unix:$DB_SOCK \
                        --pidfile \
                        --log-file=$prefix/var/log/openvswitch/ovs-vswitchd.log 2>&1 >$prefix/var/log/openvswitch/ovs-launch.txt" 
        fi
        $prefix/bin/ovs-vsctl --no-wait init
        echo "Starting vswitchd"
        echo "Started vswitchd ***************"

        echo "creating bridges"

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

        if [ $ovs_version == "2pt6" ]; then
            $prefix/bin/ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=$cpumask
            $prefix/bin/ovs-vsctl set Interface dpdk0 options:n_rxq=$num_queues_per_port
            $prefix/bin/ovs-vsctl set Interface dpdk1 options:n_rxq=$num_queues_per_port
        else
            $prefix/bin/ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=$cpumask
            $prefix/bin/ovs-vsctl set Open_vSwitch . other_config:n-dpdk-rxqs=$num_queues_per_port
        fi

        if [[ $multi_instance == "2" ]]; then
            echo "Creating 2nd set of bridges"

            # create the bridges/ports with 1 phys dev and 1 virt dev per bridge, to be used for 1 VM to forward packets
            $prefix/bin/ovs-vsctl --if-exists del-br ovsbr2
            echo "creating ovsbr2 bridge"
            $prefix/bin/ovs-vsctl add-br ovsbr2 -- set bridge ovsbr2 datapath_type=netdev
            $prefix/bin/ovs-vsctl add-port ovsbr2 dpdk2 -- set Interface dpdk2 type=dpdk
            $prefix/bin/ovs-vsctl add-port ovsbr2 vhost-user3 -- set Interface vhost-user3 type=dpdkvhostuser
            $prefix/bin/ovs-ofctl del-flows ovsbr2
            $prefix/bin/ovs-ofctl add-flow ovsbr2 "in_port=1,idle_timeout=0 actions=output:2"
            $prefix/bin/ovs-ofctl add-flow ovsbr2 "in_port=2,idle_timeout=0 actions=output:1"
            
            $prefix/bin/ovs-vsctl --if-exists del-br ovsbr3
            echo "creating ovsbr3 bridge"
            $prefix/bin/ovs-vsctl add-br ovsbr3 -- set bridge ovsbr3 datapath_type=netdev
            $prefix/bin/ovs-vsctl add-port ovsbr3 vhost-user4 -- set Interface vhost-user4 type=dpdkvhostuser
            $prefix/bin/ovs-vsctl add-port ovsbr3 dpdk3 -- set Interface dpdk3 type=dpdk
            $prefix/bin/ovs-ofctl del-flows ovsbr3
            $prefix/bin/ovs-ofctl add-flow ovsbr3 "in_port=1,idle_timeout=0 actions=output:2"
            $prefix/bin/ovs-ofctl add-flow ovsbr3 "in_port=2,idle_timeout=0 actions=output:1"

            if [ $ovs_version == "2pt6" ]; then
                $prefix/bin/ovs-vsctl set Interface dpdk2 options:n_rxq=$num_queues_per_port
                $prefix/bin/ovs-vsctl set Interface dpdk3 options:n_rxq=$num_queues_per_port
            else
                $prefix/bin/ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=$cpumask
                $prefix/bin/ovs-vsctl set Open_vSwitch . other_config:n-dpdk-rxqs=$num_queues_per_port

            fi
        fi
    fi
    ;;
"{\(PV\),\(VV\),\(VP\)}")
    # start new ovs
    mkdir -p $prefix/var/run/openvswitch
    mkdir -p $prefix/etc/openvswitch
    $prefix/bin/ovsdb-tool create $prefix/etc/openvswitch/conf.db /usr/share/openvswitch/vswitch.ovsschema
    
    rm -rf /dev/usvhost-1
    $prefix/sbin/ovsdb-server -v --remote=punix:$DB_SOCK \
        --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
        --pidfile --detach || exit 1
    

    if [[ "kernel" == $P_dataplane ]] && [[ "kernel" == $V_dataplane ]]; then
        echo "**********************************************************"
        echo "* Running {(P,V), (V,V), (V,P)} Test."
        echo "* Physical Data Plane .... kernel"
        echo "* Virtual Data Plane ..... kernel"
        echo "**********************************************************"
        
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
        echo "**********************************************************"
        echo "* Running {(P,V), (V,V), (V,P)} Test."
        echo "* Physical Data Plane .... DPDK"
        echo "* Virtual Data Plane ..... DPDK"
        echo "**********************************************************"

        screen -dmS ovs \
        sudo su -g qemu -c "umask 002; $prefix/sbin/ovs-vswitchd \
                    --dpdk $cuse_dev_opt -c 0x1 -n 3 \
                    --socket-mem 1024,1024 \
                    -- unix:$DB_SOCK \
                    --pidfile \
                    --log-file=$prefix/var/log/openvswitch/ovs-vswitchd.log 2>&1 >$prefix/var/log/openvswitch/ovs-launch.txt" 

        $prefix/bin/ovs-vsctl --no-wait init
        
        echo "creating bridges"
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
    fi
    ;;
*)
    echo "A total loser"
    ;;
esac

exit
