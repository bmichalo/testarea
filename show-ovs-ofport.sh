#!/bin/bash
ovs-vsctl show
ovs-vsctl list in | grep -e "ofport " -e "name "
