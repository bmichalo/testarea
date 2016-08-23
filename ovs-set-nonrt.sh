#!/bin/bash

echo "-1" >/proc/sys/kernel/sched_rt_runtime_us
sleep 1
ovs_pid=`pgrep ovs-vswitchd`
pushd /proc/$ovs_pid/task
for i in `/bin/ls`; do
	echo $i
	grep -q pmd $i/stat && chrt -o -p 0 $i
done
popd
