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
sudo ip netns exec host1 ping 172.20.0.2
```

## Result

```
> clone will happen at the end of Ingress Pipeline
[10:56:02.396] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Pipeline 'ingress': end
[10:56:02.396] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Cloning packet at ingress

> sorted per cloned[0.1] packet and the original packet[0.0]

> Original packet will be sent to the port specified by egress_spec (2)
> instance_type is 0 (BMV2_V1MODEL_INSTANCE_TYPE_NORMAL)
[10:56:02.396] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Cloning packet to egress port 192
[10:56:02.396] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Egress port is 2
[10:56:02.397] [bmv2] [D] [thread 36120] [0.0] [cxt 0] Pipeline 'egress': start
[10:56:02.397] [bmv2] [T] [thread 36120] [0.0] [cxt 0] Applying table 'SwitchEgress.egress_table_1'
[10:56:02.397] [bmv2] [D] [thread 36120] [0.0] [cxt 0] Looking up key:
* st_md.ingress_port  : 0001
* st_md.instance_type : 00000000
* st_md.egress_port   : 0002

> cloned packet will first go through IngressParser
[10:56:02.396] [bmv2] [D] [thread 36117] [0.1] [cxt 0] Parser 'parser': start
[10:56:02.396] [bmv2] [D] [thread 36117] [0.1] [cxt 0] Parser 'parser' entering state 'start'
[10:56:02.396] [bmv2] [D] [thread 36117] [0.1] [cxt 0] Extracting header 'ethernet'
[10:56:02.396] [bmv2] [D] [thread 36117] [0.1] [cxt 0] Parser state 'start' has no switch, going to default next state
[10:56:02.396] [bmv2] [T] [thread 36117] [0.1] [cxt 0] Bytes parsed: 14
[10:56:02.396] [bmv2] [D] [thread 36117] [0.1] [cxt 0] Parser 'parser': end
> Then move to Egress Pipeline (skip Ingress)
> egress_port will be 00c0 (192, CPU_PORT)
> instance_type is 1 (BMV2_V1MODEL_INSTANCE_TYPE_INGRESS_CLONE)
[10:56:02.397] [bmv2] [D] [thread 36118] [0.1] [cxt 0] Pipeline 'egress': start
[10:56:02.397] [bmv2] [T] [thread 36118] [0.1] [cxt 0] Applying table 'SwitchEgress.egress_table_1'
[10:56:02.397] [bmv2] [D] [thread 36118] [0.1] [cxt 0] Looking up key:
* st_md.ingress_port  : 0001
* st_md.instance_type : 00000001
* st_md.egress_port   : 00c0
```

## BMv2 LOG

```bash
[10:56:02.395] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Processing packet received on port 1
[10:56:02.395] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Parser 'parser': start
[10:56:02.395] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Parser 'parser' entering state 'start'
[10:56:02.395] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Extracting header 'ethernet'
[10:56:02.395] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Parser state 'start' has no switch, going to default next state
[10:56:02.395] [bmv2] [T] [thread 36117] [0.0] [cxt 0] Bytes parsed: 14
[10:56:02.395] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Parser 'parser': end
[10:56:02.395] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Pipeline 'ingress': start
[10:56:02.395] [bmv2] [T] [thread 36117] [0.0] [cxt 0] Applying table 'tbl_example02l158'
[10:56:02.395] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Looking up key:

[10:56:02.395] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Table 'tbl_example02l158': miss
[10:56:02.395] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Action entry is example02l158 -
[10:56:02.395] [bmv2] [T] [thread 36117] [0.0] [cxt 0] Action example02l158
[10:56:02.395] [bmv2] [T] [thread 36117] [0.0] [cxt 0] example02.p4(158) Primitive mark_to_drop(st_md)
[10:56:02.395] [bmv2] [T] [thread 36117] [0.0] [cxt 0] Applying table 'SwitchIngress.ingress_table_1'
[10:56:02.395] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Looking up key:
* st_md.ingress_port  : 0001
* st_md.instance_type : 00000000

[10:56:02.395] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Table 'SwitchIngress.ingress_table_1': miss
[10:56:02.395] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Action entry is SwitchIngress.do_clone3_i2e -
[10:56:02.395] [bmv2] [T] [thread 36117] [0.0] [cxt 0] Action SwitchIngress.do_clone3_i2e
[10:56:02.395] [bmv2] [T] [thread 36117] [0.0] [cxt 0] example02.p4(122) Primitive clone3(CloneType.I2E, I2E_CLONE_SESSION_ID, st_md)
[10:56:02.395] [bmv2] [T] [thread 36117] [0.0] [cxt 0] Applying table 'tbl_example02l160'
[10:56:02.395] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Looking up key:

[10:56:02.395] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Table 'tbl_example02l160': miss
[10:56:02.395] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Action entry is example02l160 -
[10:56:02.395] [bmv2] [T] [thread 36117] [0.0] [cxt 0] Action example02l160
[10:56:02.395] [bmv2] [T] [thread 36117] [0.0] [cxt 0] example02.p4(160) Primitive st_md.egress_spec = 2
[10:56:02.396] [bmv2] [T] [thread 36117] [0.0] [cxt 0] Applying table 'SwitchIngress.ingress_table_2'
[10:56:02.396] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Looking up key:
* st_md.ingress_port  : 0001
* st_md.instance_type : 00000000

[10:56:02.396] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Table 'SwitchIngress.ingress_table_2': miss
[10:56:02.396] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Action entry is NoAction -
[10:56:02.396] [bmv2] [T] [thread 36117] [0.0] [cxt 0] Action NoAction
[10:56:02.396] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Pipeline 'ingress': end
[10:56:02.396] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Cloning packet at ingress
[10:56:02.396] [bmv2] [D] [thread 36117] [0.1] [cxt 0] Parser 'parser': start
[10:56:02.396] [bmv2] [D] [thread 36117] [0.1] [cxt 0] Parser 'parser' entering state 'start'
[10:56:02.396] [bmv2] [D] [thread 36117] [0.1] [cxt 0] Extracting header 'ethernet'
[10:56:02.396] [bmv2] [D] [thread 36117] [0.1] [cxt 0] Parser state 'start' has no switch, going to default next state
[10:56:02.396] [bmv2] [T] [thread 36117] [0.1] [cxt 0] Bytes parsed: 14
[10:56:02.396] [bmv2] [D] [thread 36117] [0.1] [cxt 0] Parser 'parser': end
[10:56:02.396] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Cloning packet to egress port 192
[10:56:02.396] [bmv2] [D] [thread 36117] [0.0] [cxt 0] Egress port is 2
[10:56:02.397] [bmv2] [D] [thread 36118] [0.1] [cxt 0] Pipeline 'egress': start
[10:56:02.397] [bmv2] [D] [thread 36120] [0.0] [cxt 0] Pipeline 'egress': start
[10:56:02.397] [bmv2] [T] [thread 36118] [0.1] [cxt 0] Applying table 'SwitchEgress.egress_table_1'
[10:56:02.397] [bmv2] [T] [thread 36120] [0.0] [cxt 0] Applying table 'SwitchEgress.egress_table_1'
[10:56:02.397] [bmv2] [D] [thread 36118] [0.1] [cxt 0] Looking up key:
* st_md.ingress_port  : 0001
* st_md.instance_type : 00000001
* st_md.egress_port   : 00c0

[10:56:02.397] [bmv2] [D] [thread 36120] [0.0] [cxt 0] Looking up key:
* st_md.ingress_port  : 0001
* st_md.instance_type : 00000000
* st_md.egress_port   : 0002

[10:56:02.397] [bmv2] [D] [thread 36118] [0.1] [cxt 0] Table 'SwitchEgress.egress_table_1': miss
[10:56:02.397] [bmv2] [D] [thread 36120] [0.0] [cxt 0] Table 'SwitchEgress.egress_table_1': miss
[10:56:02.397] [bmv2] [D] [thread 36118] [0.1] [cxt 0] Action entry is NoAction -
[10:56:02.397] [bmv2] [D] [thread 36120] [0.0] [cxt 0] Action entry is NoAction -
[10:56:02.397] [bmv2] [T] [thread 36118] [0.1] [cxt 0] Action NoAction
[10:56:02.397] [bmv2] [T] [thread 36120] [0.0] [cxt 0] Action NoAction
[10:56:02.397] [bmv2] [D] [thread 36118] [0.1] [cxt 0] Pipeline 'egress': end
[10:56:02.397] [bmv2] [D] [thread 36120] [0.0] [cxt 0] Pipeline 'egress': end
[10:56:02.397] [bmv2] [D] [thread 36118] [0.1] [cxt 0] Deparser 'deparser': start
[10:56:02.397] [bmv2] [D] [thread 36120] [0.0] [cxt 0] Deparser 'deparser': start
[10:56:02.397] [bmv2] [D] [thread 36118] [0.1] [cxt 0] Deparsing header 'ethernet'
[10:56:02.397] [bmv2] [D] [thread 36120] [0.0] [cxt 0] Deparsing header 'ethernet'
[10:56:02.397] [bmv2] [D] [thread 36118] [0.1] [cxt 0] Deparser 'deparser': end
[10:56:02.397] [bmv2] [D] [thread 36120] [0.0] [cxt 0] Deparser 'deparser': end
[10:56:02.397] [bmv2] [D] [thread 36122] [0.1] [cxt 0] Transmitting packet of size 42 out of port 192
[10:56:02.397] [bmv2] [D] [thread 36122] Transmitting packet-in
PACKET IN
[10:56:02.398] [bmv2] [D] [thread 36122] [0.0] [cxt 0] Transmitting packet of size 42 out of port 2
```
