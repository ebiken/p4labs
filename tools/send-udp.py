#!/usr/bin/python

import os
import sys

if os.getuid() !=0:
    print """
ERROR: This script requires root privileges. 
       Use 'sudo' to run it.
"""
    quit()

from scapy.all import *

try:
    ip_dst = sys.argv[1]
except:
    ip_dst = "172.20.0.2"

print "Sending IP packet to", ip_dst
p = (Ether(dst="02:03:04:05:06:02", src="02:03:04:05:06:01")/
        IP(src="172.20.0.1", dst=ip_dst)/UDP(sport=7,dport=7)/
        "XXXXXXXX")
sendp(p, iface="veth1") 
