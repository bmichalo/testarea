#!/bin/bash
watch -n0.1 --no-title "grep -e CPU0 -e p2p1 -e p2p2 /proc/interrupts"
