#!/bin/bash

cpumask=( $@ )
ovs_pid=`pgrep ovs-vswitchd`
pushd /proc/$ovs_pid/task
j=0
for i in `/bin/ls`; do
	if grep -q pmd $i/stat; then
		echo going to pin task $i to cpu ${cpumask[$j]}
		taskset -pc ${cpumask[$j]} $i
		let j=$j+1
	fi
done
popd
