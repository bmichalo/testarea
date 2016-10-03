#!/bin/bash
/bin/ovs-ofctl del-flows ovsbr0
/bin/ovs-ofctl del-flows ovsbr1

#/bin/ovs-ofctl add-flow ovsbr0 "in_port=2,idle_timeout=0 actions=output:1"
#/bin/ovs-ofctl add-flow ovsbr0 "in_port=1,idle_timeout=0 actions=output:2"
#/bin/ovs-ofctl add-flow ovsbr1 "in_port=2,idle_timeout=0 actions=output:1"
#/bin/ovs-ofctl add-flow ovsbr1 "in_port=1,idle_timeout=0 actions=output:2"
/bin/ovs-ofctl add-flow ovsbr0 "in_port=$2,idle_timeout=0 actions=output:$1"
/bin/ovs-ofctl add-flow ovsbr0 "in_port=$1,idle_timeout=0 actions=output:$2"
/bin/ovs-ofctl add-flow ovsbr1 "in_port=$2,idle_timeout=0 actions=output:$1"
/bin/ovs-ofctl add-flow ovsbr1 "in_port=$1,idle_timeout=0 actions=output:$2"
