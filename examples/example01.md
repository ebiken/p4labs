# Example 01: Check egress_spec and egress_port after mark_to_drop(st_md) was called.

```
#sudo ip netns exec host2 ethtool --offload veth2 rx off tx off
#sudo ip netns exec host1 ethtool --offload veth1 rx off tx off

make 01
sudo ./bmv2-env.sh -c 2
sudo simple_switch build.bmv2/example01.json -i 1@vtap1 -i 2@vtap2 --log-console -L trace
```

## Result

From the result, you can confirm:

* egreess_port is set after end of the Ingress pipeline
* By mark_to_drop(st_md), egress_spec will be 0x01ff (511) and mcast_grp will be 0 (zero)
* If mcast_grp != 0:
    * egress_spec will be ignored.
    * egress_port will be set for each packet based on mgrp setting. 

## Logs of the results:

mark_to_drop(st_md) between ingress_table_2 and 3:

```
[12:08:49.292] [bmv2] [D] [thread 25789] [2.0] [cxt 0] Pipeline 'ingress': start
[12:08:49.292] [bmv2] [T] [thread 25789] [2.0] [cxt 0] Applying table 'SwitchIngress.ingress_table_1'
[12:08:49.292] [bmv2] [D] [thread 25789] [2.0] [cxt 0] Looking up key:
* st_md.egress_spec   : 0000
* st_md.egress_port   : 0000
* st_md.mcast_grp     : 0000

[12:08:49.292] [bmv2] [T] [thread 25789] [2.0] [cxt 0] Applying table 'SwitchIngress.ingress_table_2'
[12:08:49.292] [bmv2] [D] [thread 25789] [2.0] [cxt 0] Looking up key:
* st_md.egress_spec   : 0008
* st_md.egress_port   : 0000
* st_md.mcast_grp     : 0008

>> mark_to_drop(st_md)

[12:08:49.293] [bmv2] [T] [thread 25789] [2.0] [cxt 0] Applying table 'SwitchIngress.ingress_table_3'
[12:08:49.293] [bmv2] [D] [thread 25789] [2.0] [cxt 0] Looking up key:
* st_md.egress_spec   : 01ff
* st_md.egress_port   : 0000
* st_md.mcast_grp     : 0000

[12:09:46.061] [bmv2] [D] [thread 25789] [3.0] [cxt 0] Pipeline 'ingress': end
[12:09:46.061] [bmv2] [D] [thread 25789] [3.0] [cxt 0] Egress port is 511
[12:09:46.061] [bmv2] [D] [thread 25789] [3.0] [cxt 0] Dropping packet at the end of ingress

>> Would not reach SwitchEgress pipeline.
```

Without setting mcast_grp and commenting out mark_to_drop(st_md):

```
[12:16:45.813] [bmv2] [D] [thread 25882] [5.0] [cxt 0] Pipeline 'ingress': start
[12:16:45.813] [bmv2] [T] [thread 25882] [5.0] [cxt 0] Applying table 'SwitchIngress.ingress_table_1'
[12:16:45.814] [bmv2] [D] [thread 25882] [5.0] [cxt 0] Looking up key:
* st_md.egress_spec   : 0000
* st_md.egress_port   : 0000

[12:16:45.814] [bmv2] [T] [thread 25882] [5.0] [cxt 0] Applying table 'SwitchIngress.ingress_table_2'
[12:16:45.814] [bmv2] [D] [thread 25882] [5.0] [cxt 0] Looking up key:
* st_md.egress_spec   : 0008
* st_md.egress_port   : 0000

[12:16:45.814] [bmv2] [T] [thread 25882] [5.0] [cxt 0] Applying table 'SwitchIngress.ingress_table_3'
[12:16:45.814] [bmv2] [D] [thread 25882] [5.0] [cxt 0] Looking up key:
* st_md.egress_spec   : 0008
* st_md.egress_port   : 0000

[12:16:45.814] [bmv2] [D] [thread 25882] [5.0] [cxt 0] Pipeline 'ingress': end
[12:16:45.814] [bmv2] [D] [thread 25882] [5.0] [cxt 0] Egress port is 8
[12:16:45.814] [bmv2] [D] [thread 25883] [5.0] [cxt 0] Pipeline 'egress': start
[12:16:45.814] [bmv2] [T] [thread 25883] [5.0] [cxt 0] Applying table 'SwitchEgress.egress_table_1'
[12:16:45.814] [bmv2] [D] [thread 25883] [5.0] [cxt 0] Looking up key:
* st_md.egress_spec   : 0000
* st_md.egress_port   : 0008
```

Setting mcast_grp and commenting out mark_to_drop(st_md):

```
[12:28:28.844] [bmv2] [T] [thread 26106] [2.0] [cxt 0] Applying table 'SwitchIngress.ingress_table_1'
[12:28:28.844] [bmv2] [D] [thread 26106] [2.0] [cxt 0] Looking up key:
* st_md.egress_spec   : 0000
* st_md.egress_port   : 0000
* st_md.mcast_grp     : 0000

[12:28:28.844] [bmv2] [T] [thread 26106] [2.0] [cxt 0] Applying table 'SwitchIngress.ingress_table_2'
[12:28:28.844] [bmv2] [D] [thread 26106] [2.0] [cxt 0] Looking up key:
* st_md.egress_spec   : 0008
* st_md.egress_port   : 0000
* st_md.mcast_grp     : 0008

[12:28:28.845] [bmv2] [T] [thread 26106] [2.0] [cxt 0] Applying table 'SwitchIngress.ingress_table_3'
[12:28:28.845] [bmv2] [D] [thread 26106] [2.0] [cxt 0] Looking up key:
* st_md.egress_spec   : 0008
* st_md.egress_port   : 0000
* st_md.mcast_grp     : 0008

[12:28:28.845] [bmv2] [D] [thread 26106] [2.0] [cxt 0] Pipeline 'ingress': end
[12:28:28.845] [bmv2] [D] [thread 26106] [2.0] [cxt 0] Multicast requested for packet
[12:28:28.845] [bmv2] [W] [thread 26106] Replication requested for mgid 8, which is not known to the PRE
```

Setting mcast_grp, config mgid 8, and commenting out mark_to_drop(st_md):

```bash
$ simple_switch_CLI
Obtaining JSON from switch...
mc_node_create 65000 1
mc_node_create 65000 2
mc_mgrp_create 8
mc_node_associate 8 0
mc_node_associate 8 1

RuntimeCmd: mc_dump
==========
MC ENTRIES
**********
mgrp(8)
  -> (L1h=0, rid=65000) -> (ports=[2], lags=[])
  -> (L1h=1, rid=65000) -> (ports=[1], lags=[])
==========
LAGS
==========

[12:38:25.102] [bmv2] [D] [thread 26125] [15.0] [cxt 0] Pipeline 'ingress': start
[12:38:25.102] [bmv2] [T] [thread 26125] [15.0] [cxt 0] Applying table 'SwitchIngress.ingress_table_1'
[12:38:25.102] [bmv2] [D] [thread 26125] [15.0] [cxt 0] Looking up key:
* st_md.egress_spec   : 0000
* st_md.egress_port   : 0000
* st_md.mcast_grp     : 0000

[12:38:25.102] [bmv2] [T] [thread 26125] [15.0] [cxt 0] Applying table 'SwitchIngress.ingress_table_2'
[12:38:25.102] [bmv2] [D] [thread 26125] [15.0] [cxt 0] Looking up key:
* st_md.egress_spec   : 0008
* st_md.egress_port   : 0000
* st_md.mcast_grp     : 0008

[12:38:25.102] [bmv2] [T] [thread 26125] [15.0] [cxt 0] Applying table 'SwitchIngress.ingress_table_3'
[12:38:25.102] [bmv2] [D] [thread 26125] [15.0] [cxt 0] Looking up key:
* st_md.egress_spec   : 0008
* st_md.egress_port   : 0000
* st_md.mcast_grp     : 0008

[12:38:25.102] [bmv2] [D] [thread 26125] [15.0] [cxt 0] Pipeline 'ingress': end
[12:38:25.102] [bmv2] [D] [thread 26125] [15.0] [cxt 0] Multicast requested for packet
[12:38:25.102] [bmv2] [D] [thread 26125] number of packets replicated : 2
[12:38:25.102] [bmv2] [D] [thread 26125] [15.0] [cxt 0] Replicating packet on port 2
[12:38:25.103] [bmv2] [D] [thread 26125] [15.0] [cxt 0] Replicating packet on port 1

>> sorted based on reprecated packet: [15.1] and [15.2]
>> If mcast_grp != 0, then egress_port will be set for each packet based on mgrp setting

[12:38:25.103] [bmv2] [D] [thread 26128] [15.1] [cxt 0] Pipeline 'egress': start
[12:38:25.103] [bmv2] [T] [thread 26128] [15.1] [cxt 0] Applying table 'SwitchEgress.egress_table_1'
[12:38:25.103] [bmv2] [D] [thread 26128] [15.1] [cxt 0] Looking up key:
* st_md.egress_spec   : 0000
* st_md.egress_port   : 0002
* st_md.mcast_grp     : 0008
[12:38:25.103] [bmv2] [D] [thread 26128] [15.1] [cxt 0] Table 'SwitchEgress.egress_table_1': miss
[12:38:25.103] [bmv2] [D] [thread 26128] [15.1] [cxt 0] Action entry is NoAction -
[12:38:25.103] [bmv2] [T] [thread 26128] [15.1] [cxt 0] Action NoAction
[12:38:25.103] [bmv2] [D] [thread 26128] [15.1] [cxt 0] Pipeline 'egress': end
[12:38:25.103] [bmv2] [D] [thread 26128] [15.1] [cxt 0] Deparser 'deparser': start
[12:38:25.103] [bmv2] [D] [thread 26128] [15.1] [cxt 0] Deparsing header 'ethernet'
[12:38:25.103] [bmv2] [D] [thread 26128] [15.1] [cxt 0] Deparser 'deparser': end
[12:38:25.103] [bmv2] [D] [thread 26130] [15.1] [cxt 0] Transmitting packet of size 42 out of port 2

[12:38:25.103] [bmv2] [D] [thread 26127] [15.2] [cxt 0] Pipeline 'egress': start
[12:38:25.103] [bmv2] [T] [thread 26127] [15.2] [cxt 0] Applying table 'SwitchEgress.egress_table_1'
[12:38:25.103] [bmv2] [D] [thread 26127] [15.2] [cxt 0] Looking up key:
* st_md.egress_spec   : 0000
* st_md.egress_port   : 0001
* st_md.mcast_grp     : 0008
[12:38:25.103] [bmv2] [D] [thread 26127] [15.2] [cxt 0] Table 'SwitchEgress.egress_table_1': miss
[12:38:25.103] [bmv2] [D] [thread 26127] [15.2] [cxt 0] Action entry is NoAction -
[12:38:25.103] [bmv2] [T] [thread 26127] [15.2] [cxt 0] Action NoAction
[12:38:25.103] [bmv2] [D] [thread 26127] [15.2] [cxt 0] Pipeline 'egress': end
[12:38:25.103] [bmv2] [D] [thread 26127] [15.2] [cxt 0] Deparser 'deparser': start
[12:38:25.103] [bmv2] [D] [thread 26127] [15.2] [cxt 0] Deparsing header 'ethernet'
[12:38:25.103] [bmv2] [D] [thread 26127] [15.2] [cxt 0] Deparser 'deparser': end
[12:38:25.103] [bmv2] [D] [thread 26130] [15.2] [cxt 0] Transmitting packet of size 42 out of port 1
```
