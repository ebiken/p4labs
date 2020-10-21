# Example 02: Sending packet to both CPU and specific ports (clone)

This example shows how to clone packet to CPU and also process the original packet as usual.
(Actually you can clone packet to any port and not specific to CPU_PORT)

To clone a packet, you need to set "clone session id" (or so called mirroring sessions).

For more information, refer to the details explained in BMv2 (behavior-model) documents:
* [mirroring_add, mirroring_add_mc, mirroring_delete, mirroring_get](https://github.com/p4lang/behavioral-model/blob/master/docs/runtime_CLI.md#mirroring_add-mirroring_add_mc-mirroring_delete-mirroring_get)
* [Pseudocode for what happens at the end of ingress and egress processing](https://github.com/p4lang/behavioral-model/blob/master/docs/simple_switch.md#pseudocode-for-what-happens-at-the-end-of-ingress-and-egress-processing)

```
> compile P4 code
make 02

> create two veth pairs
sudo ./bmv2-env.sh -c 2

> run BMv2
> sudo simple_switch_grpc --no-p4 -i 1@vtap1 -i 2@vtap2 --log-console -L trace \
> -- --grpc-server-addr 0.0.0.0:50051 --cpu-port 192
sudo make run02

> run Go P4Runtime agent.
sudo go run example02.go

> Add clone session id 0 with target port CPU_PORT(192)
> You cal also add multicast group using `mirroring_add_mc <mirror_id> <mgrp>
> RuntimeCmd: help mirroring_add
> Add mirroring session to unicast port: mirroring_add <mirror_id> <egress_port>
> RuntimeCmd: help mirroring_add_mc
> Add mirroring session to multicast group: mirroring_add_mc <mirror_id> <mgrp>

> smiple_switch_CLI:
mirroring_add 0 192

> Send any packt to any port, and the packet will be cloned to CPU and also sent out from port#2.
> Below script will send UDP from veth1 using scapy.
~/p4labs/tools$ sudo ip netns exec host1 ./send-udp.py
```

## Result

* Go P4Runtime Client Log (example02.go)

```bash
> hdr.packet_in.is_clone (metadata_id:2) is 1
2020/10/21 11:47:22 PacketIn: Packet from switch.
2020/10/21 11:47:22 | Metadata: [metadata_id:1 value:"\000\001"  metadata_id:2 value:"\001"  metadata_id:3 value:"\000" ]
2020/10/21 11:47:22 | Dst: 02:03:04:05:06:02
2020/10/21 11:47:22 | Src: 02:03:04:05:06:01
2020/10/21 11:47:22 | Ethertype: 0800
2020/10/21 11:47:22 | Packet Dump:
00000000  02 03 04 05 06 02 02 03  04 05 06 01 08 00 45 00  |..............E.|
00000010  00 24 00 01 00 00 40 11  22 9d ac 14 00 01 ac 14  |.$....@.".......|
00000020  00 02 00 07 00 07 00 10  46 33 58 58 58 58 58 58  |........F3XXXXXX|
00000030  58 58                                             |XX|
```

* BMv2 Log

```
> clone will happen at the end of Ingress Pipeline
[11:47:22.371] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Pipeline 'ingress': end
[11:47:22.371] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Cloning packet at ingress

> sorted per cloned packet[0.1] and the original packet[0.0]

>>> Original packet will be sent to the port specified by egress_spec (2)
> instance_type is 0 (BMV2_V1MODEL_INSTANCE_TYPE_NORMAL)
> Condition "st_md.egress_port == 9w192" is false, so packet_in header would not be set valid.
> Deparsing only 'ethernet' header.
[11:47:22.372] [bmv2] [T] [thread 41417] [0.0] [cxt 0] example02.p4(177) Condition "st_md.egress_port == 9w192" (node_8) is false
[11:47:22.372] [bmv2] [T] [thread 41417] [0.0] [cxt 0] Applying table 'SwitchEgress.egress_table_1'
[11:47:22.372] [bmv2] [D] [thread 41417] [0.0] [cxt 0] Looking up key:
* st_md.ingress_port  : 0001
* st_md.instance_type : 00000000
* st_md.egress_port   : 0002

[11:47:22.372] [bmv2] [D] [thread 41417] [0.0] [cxt 0] Deparser 'deparser': start
[11:47:22.372] [bmv2] [D] [thread 41417] [0.0] [cxt 0] Deparsing header 'ethernet'
[11:47:22.372] [bmv2] [D] [thread 41417] [0.0] [cxt 0] Deparser 'deparser': end
[11:47:22.372] [bmv2] [D] [thread 41419] [0.0] [cxt 0] Transmitting packet of size 50 out of port 2

>>> cloned packet will first go through IngressParser
[11:47:22.371] [bmv2] [D] [thread 41414] [0.1] [cxt 0] Parser 'parser': start
[11:47:22.371] [bmv2] [D] [thread 41414] [0.1] [cxt 0] Parser 'parser' entering state 'start'
[11:47:22.371] [bmv2] [D] [thread 41414] [0.1] [cxt 0] Extracting header 'ethernet'
[11:47:22.371] [bmv2] [D] [thread 41414] [0.1] [cxt 0] Parser state 'start' has no switch, going to default next state
[11:47:22.371] [bmv2] [T] [thread 41414] [0.1] [cxt 0] Bytes parsed: 14
[11:47:22.371] [bmv2] [D] [thread 41414] [0.1] [cxt 0] Parser 'parser': end
> Then move to Egress Pipeline (skip Ingress)
> Condition "st_md.egress_port == 9w192" is true, so packet_in header would be set valid.
[11:47:22.372] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Pipeline 'egress': start
[11:47:22.372] [bmv2] [T] [thread 41415] [0.1] [cxt 0] example02.p4(177) Condition "st_md.egress_port == 9w192" (node_8) is true
[11:47:22.372] [bmv2] [T] [thread 41415] [0.1] [cxt 0] Applying table 'tbl_example02l178'
[11:47:22.372] [bmv2] [T] [thread 41415] [0.1] [cxt 0] example02.p4(178) Primitive hdr.packet_in.setValid()
[11:47:22.372] [bmv2] [T] [thread 41415] [0.1] [cxt 0] example02.p4(179) Primitive hdr.packet_in.ingress_port = ((PortIdP4Runtime_t)(st_md.ingress_port)
[11:47:22.372] [bmv2] [T] [thread 41415] [0.1] [cxt 0] example02.p4(180) Condition "(st_md.instance_type == BMV2_V1MODEL_INSTANCE_TYPE_INGRESS_CLONE) || (st_md.instance_type == BMV2_V1MODEL_INSTANCE_TYPE_EGRESS_CLONE)" (node_10) is true
[11:47:22.372] [bmv2] [T] [thread 41415] [0.1] [cxt 0] example02.p4(181) Primitive hdr.packet_in.is_clone = 1
[11:47:22.373] [bmv2] [T] [thread 41415] [0.1] [cxt 0] example02.p4(185) Primitive hdr.packet_in.padding = 0

> egress_port will be 00c0 (192, CPU_PORT)
> instance_type is 1 (BMV2_V1MODEL_INSTANCE_TYPE_INGRESS_CLONE)
[11:47:22.373] [bmv2] [T] [thread 41415] [0.1] [cxt 0] Applying table 'SwitchEgress.egress_table_1'
[11:47:22.373] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Looking up key:
* st_md.ingress_port  : 0001
* st_md.instance_type : 00000001
* st_md.egress_port   : 00c0
[11:47:22.373] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Pipeline 'egress': end
[11:47:22.373] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Deparser 'deparser': start
[11:47:22.373] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Deparsing header 'packet_in'
[11:47:22.373] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Deparsing header 'ethernet'
[11:47:22.373] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Deparser 'deparser': end
[11:47:22.373] [bmv2] [D] [thread 41419] [0.1] [cxt 0] Transmitting packet of size 53 out of port 192
[11:47:22.373] [bmv2] [D] [thread 41419] Transmitting packet-in
PACKET IN

```

## BMv2 RAW LOG

```bash
[11:47:22.370] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Processing packet received on port 1
[11:47:22.370] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Parser 'parser': start
[11:47:22.370] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Parser 'parser' entering state 'start'
[11:47:22.370] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Extracting header 'ethernet'
[11:47:22.370] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Parser state 'start' has no switch, going to default next state
[11:47:22.370] [bmv2] [T] [thread 41414] [0.0] [cxt 0] Bytes parsed: 14
[11:47:22.370] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Parser 'parser': end
[11:47:22.370] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Pipeline 'ingress': start
[11:47:22.370] [bmv2] [T] [thread 41414] [0.0] [cxt 0] Applying table 'tbl_example02l154'
[11:47:22.370] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Looking up key:

[11:47:22.370] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Table 'tbl_example02l154': miss
[11:47:22.370] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Action entry is example02l154 -
[11:47:22.370] [bmv2] [T] [thread 41414] [0.0] [cxt 0] Action example02l154
[11:47:22.370] [bmv2] [T] [thread 41414] [0.0] [cxt 0] example02.p4(154) Primitive mark_to_drop(st_md)
[11:47:22.370] [bmv2] [T] [thread 41414] [0.0] [cxt 0] Applying table 'SwitchIngress.ingress_table_1'
[11:47:22.370] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Looking up key:
* st_md.ingress_port  : 0001
* st_md.instance_type : 00000000

[11:47:22.370] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Table 'SwitchIngress.ingress_table_1': miss
[11:47:22.370] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Action entry is SwitchIngress.do_clone3_i2e -
[11:47:22.371] [bmv2] [T] [thread 41414] [0.0] [cxt 0] Action SwitchIngress.do_clone3_i2e
[11:47:22.371] [bmv2] [T] [thread 41414] [0.0] [cxt 0] example02.p4(118) Primitive clone3(CloneType.I2E, I2E_CLONE_SESSION_ID, st_md)
[11:47:22.371] [bmv2] [T] [thread 41414] [0.0] [cxt 0] Applying table 'tbl_example02l156'
[11:47:22.371] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Looking up key:

[11:47:22.371] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Table 'tbl_example02l156': miss
[11:47:22.371] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Action entry is example02l156 -
[11:47:22.371] [bmv2] [T] [thread 41414] [0.0] [cxt 0] Action example02l156
[11:47:22.371] [bmv2] [T] [thread 41414] [0.0] [cxt 0] example02.p4(156) Primitive st_md.egress_spec = 2
[11:47:22.371] [bmv2] [T] [thread 41414] [0.0] [cxt 0] Applying table 'SwitchIngress.ingress_table_2'
[11:47:22.371] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Looking up key:
* st_md.ingress_port  : 0001
* st_md.instance_type : 00000000

[11:47:22.371] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Table 'SwitchIngress.ingress_table_2': miss
[11:47:22.371] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Action entry is NoAction -
[11:47:22.371] [bmv2] [T] [thread 41414] [0.0] [cxt 0] Action NoAction
[11:47:22.371] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Pipeline 'ingress': end
[11:47:22.371] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Cloning packet at ingress
[11:47:22.371] [bmv2] [D] [thread 41414] [0.1] [cxt 0] Parser 'parser': start
[11:47:22.371] [bmv2] [D] [thread 41414] [0.1] [cxt 0] Parser 'parser' entering state 'start'
[11:47:22.371] [bmv2] [D] [thread 41414] [0.1] [cxt 0] Extracting header 'ethernet'
[11:47:22.371] [bmv2] [D] [thread 41414] [0.1] [cxt 0] Parser state 'start' has no switch, going to default next state
[11:47:22.371] [bmv2] [T] [thread 41414] [0.1] [cxt 0] Bytes parsed: 14
[11:47:22.371] [bmv2] [D] [thread 41414] [0.1] [cxt 0] Parser 'parser': end
[11:47:22.371] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Cloning packet to egress port 192
[11:47:22.372] [bmv2] [D] [thread 41414] [0.0] [cxt 0] Egress port is 2

[11:47:22.372] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Pipeline 'egress': start
[11:47:22.372] [bmv2] [D] [thread 41417] [0.0] [cxt 0] Pipeline 'egress': start
[11:47:22.372] [bmv2] [T] [thread 41415] [0.1] [cxt 0] example02.p4(177) Condition "st_md.egress_port == 9w192" (node_8) is true
[11:47:22.372] [bmv2] [T] [thread 41415] [0.1] [cxt 0] Applying table 'tbl_example02l178'
[11:47:22.372] [bmv2] [T] [thread 41417] [0.0] [cxt 0] example02.p4(177) Condition "st_md.egress_port == 9w192" (node_8) is false
[11:47:22.372] [bmv2] [T] [thread 41417] [0.0] [cxt 0] Applying table 'SwitchEgress.egress_table_1'
[11:47:22.372] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Looking up key:

[11:47:22.372] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Table 'tbl_example02l178': miss
[11:47:22.372] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Action entry is example02l178 -
[11:47:22.372] [bmv2] [D] [thread 41417] [0.0] [cxt 0] Looking up key:
* st_md.ingress_port  : 0001
* st_md.instance_type : 00000000
* st_md.egress_port   : 0002

[11:47:22.372] [bmv2] [T] [thread 41415] [0.1] [cxt 0] Action example02l178
[11:47:22.372] [bmv2] [D] [thread 41417] [0.0] [cxt 0] Table 'SwitchEgress.egress_table_1': miss
[11:47:22.372] [bmv2] [T] [thread 41415] [0.1] [cxt 0] example02.p4(178) Primitive hdr.packet_in.setValid()
[11:47:22.372] [bmv2] [D] [thread 41417] [0.0] [cxt 0] Action entry is NoAction -
[11:47:22.372] [bmv2] [T] [thread 41415] [0.1] [cxt 0] example02.p4(179) Primitive hdr.packet_in.ingress_port = ((PortIdP4Runtime_t)(st_md.ingress_port)
[11:47:22.372] [bmv2] [T] [thread 41417] [0.0] [cxt 0] Action NoAction
[11:47:22.372] [bmv2] [D] [thread 41417] [0.0] [cxt 0] Pipeline 'egress': end
[11:47:22.372] [bmv2] [T] [thread 41415] [0.1] [cxt 0] example02.p4(180) Condition "(st_md.instance_type == BMV2_V1MODEL_INSTANCE_TYPE_INGRESS_CLONE) || (st_md.instance_type == BMV2_V1MODEL_INSTANCE_TYPE_EGRESS_CLONE)" (node_10) is true
[11:47:22.372] [bmv2] [D] [thread 41417] [0.0] [cxt 0] Deparser 'deparser': start
[11:47:22.372] [bmv2] [T] [thread 41415] [0.1] [cxt 0] Applying table 'tbl_example02l181'
[11:47:22.372] [bmv2] [D] [thread 41417] [0.0] [cxt 0] Deparsing header 'ethernet'
[11:47:22.372] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Looking up key:

[11:47:22.372] [bmv2] [D] [thread 41417] [0.0] [cxt 0] Deparser 'deparser': end
[11:47:22.372] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Table 'tbl_example02l181': miss
[11:47:22.372] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Action entry is example02l181 -
[11:47:22.372] [bmv2] [T] [thread 41415] [0.1] [cxt 0] Action example02l181
[11:47:22.372] [bmv2] [T] [thread 41415] [0.1] [cxt 0] example02.p4(181) Primitive hdr.packet_in.is_clone = 1
[11:47:22.372] [bmv2] [T] [thread 41415] [0.1] [cxt 0] Applying table 'tbl_example02l185'
[11:47:22.372] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Looking up key:

[11:47:22.372] [bmv2] [D] [thread 41419] [0.0] [cxt 0] Transmitting packet of size 50 out of port 2
[11:47:22.372] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Table 'tbl_example02l185': miss
[11:47:22.372] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Action entry is example02l185 -
[11:47:22.372] [bmv2] [T] [thread 41415] [0.1] [cxt 0] Action example02l185
[11:47:22.373] [bmv2] [T] [thread 41415] [0.1] [cxt 0] example02.p4(185) Primitive hdr.packet_in.padding = 0
[11:47:22.373] [bmv2] [T] [thread 41415] [0.1] [cxt 0] Applying table 'SwitchEgress.egress_table_1'
[11:47:22.373] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Looking up key:
* st_md.ingress_port  : 0001
* st_md.instance_type : 00000001
* st_md.egress_port   : 00c0

[11:47:22.373] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Table 'SwitchEgress.egress_table_1': miss
[11:47:22.373] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Action entry is NoAction -
[11:47:22.373] [bmv2] [T] [thread 41415] [0.1] [cxt 0] Action NoAction
[11:47:22.373] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Pipeline 'egress': end
[11:47:22.373] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Deparser 'deparser': start
[11:47:22.373] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Deparsing header 'packet_in'
[11:47:22.373] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Deparsing header 'ethernet'
[11:47:22.373] [bmv2] [D] [thread 41415] [0.1] [cxt 0] Deparser 'deparser': end

[11:47:22.373] [bmv2] [D] [thread 41419] [0.1] [cxt 0] Transmitting packet of size 53 out of port 192
[11:47:22.373] [bmv2] [D] [thread 41419] Transmitting packet-in
PACKET IN
```
