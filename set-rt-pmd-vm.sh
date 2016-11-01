#!/bin/bash
echo "-1" >/proc/sys/kernel/sched_rt_runtime_us
testpmd_pid=`pgrep -x testpmd`
echo "testpmd_pid = $testpmd_pid"
pushd "/proc/$testpmd_pid/task"
for i in `/bin/ls`; do
    grep lcore-slave $i/stat && chrt -f -p 95 $i
done
popd

