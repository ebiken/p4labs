# example: digest

How to send P4 digest via P4Runtime to a Golang Control Plane agent.

## Target BMv2

1. Compile P4 code.

```
$ p4c --std p4_16 -b bmv2 --p4runtime-files build.bmv2/bmv2-digest.p4info.txt -o build.bmv2 bmv2-digest.p4
$ ls build.bmv2/
bmv2-digest.json  bmv2-digest.p4i  bmv2-digest.p4info.txt
```

2. Create vtap pair and assign to a namespace (vhost)

```
$ sudo ./bmv2-digest-env.sh -c 1

$ ip netns
host1 (id: 0)
$ ip a | grep vtap
7: vtap1@if8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
$ sudo ip netns exec host1 ip a | grep veth1
8: veth1@if7: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    inet 172.20.0.1/24 scope global veth1

  ns: host1
  +-------+
  | veth1 |
  +---+---+
      |
    vtap1
# vtap1 will be connected to BMv2
```

3. Run BMv2 with P4Runtime (grpc) enabled

```
$ sudo simple_switch_grpc --no-p4 -i 1@vtap1 --log-console -L trace \
-- --grpc-server-addr 0.0.0.0:50051
```

4. Run p4digest_agent

```
> run p4digest_agent

$ go run p4digest_agent.go
 ... snip ...
2020/06/28 10:55:52 Start loop to receive digest
```

BMv2 consol log
```
New connection
P4Runtime SetForwardingPipelineConfig
[10:55:52.148] [bmv2] [D] [thread 27055] Set default default entry for table 'SwitchIngress.digest_table': SwitchIngress.send_digest -
P4Runtime Write
election_id {
  low: 1
}
updates {
  type: INSERT
  entity {
    digest_entry {
      digest_id: 402184575
      config {
        max_list_size: 1
      }
    }
  }
}
```

5. Send ARP request to trigger digest and check p4digest_agent output and BMv2 debug logs

```
$ sudo ip netns exec host1 ping 172.20.0.2
> arp packet would be sent out to vtap1 (port#1 on BMv2)
```

* p4digest_agent
```
2020/06/28 10:55:58 Received DigestList message
2020/06/28 10:55:58 | smac:  02:03:04:05:06:01
2020/06/28 10:55:58 | port id:  [0 1]
```

* BMv2 debug log on console
```
[12:31:28.889] [bmv2] [D] [thread 31796] [15.0] [cxt 0] Processing packet received on port 1
[12:31:28.889] [bmv2] [D] [thread 31796] [15.0] [cxt 0] Parser 'parser': start
[12:31:28.889] [bmv2] [D] [thread 31796] [15.0] [cxt 0] Parser 'parser' entering state 'start'
[12:31:28.889] [bmv2] [D] [thread 31796] [15.0] [cxt 0] Extracting header 'ether'
[12:31:28.889] [bmv2] [D] [thread 31796] [15.0] [cxt 0] Parser state 'start' has no switch, going to default next state
[12:31:28.889] [bmv2] [T] [thread 31796] [15.0] [cxt 0] Bytes parsed: 14
[12:31:28.889] [bmv2] [D] [thread 31796] [15.0] [cxt 0] Parser 'parser': end
[12:31:28.889] [bmv2] [D] [thread 31796] [15.0] [cxt 0] Pipeline 'ingress': start
[12:31:28.889] [bmv2] [T] [thread 31796] [15.0] [cxt 0] Applying table 'SwitchIngress.digest_table'
[12:31:28.889] [bmv2] [D] [thread 31796] [15.0] [cxt 0] Looking up key:
* st_md.ingress_port  : 0001

[12:31:28.889] [bmv2] [D] [thread 31796] [15.0] [cxt 0] Table 'SwitchIngress.digest_table': miss
[12:31:28.889] [bmv2] [D] [thread 31796] [15.0] [cxt 0] Action entry is SwitchIngress.send_digest -
[12:31:28.889] [bmv2] [T] [thread 31796] [15.0] [cxt 0] Action SwitchIngress.send_digest
[12:31:28.889] [bmv2] [T] [thread 31796] [15.0] [cxt 0] bmv2-digest.p4(81) Primitive hdr.ether.srcAddr
[12:31:28.889] [bmv2] [T] [thread 31796] [15.0] [cxt 0] bmv2-digest.p4(81) Primitive st_md.ingress_port
[12:31:28.889] [bmv2] [T] [thread 31796] [15.0] [cxt 0] bmv2-digest.p4(81) Primitive digest<mac_learn_digest_t>(1, {hdr.ether.srcAddr, st_md.ingress_port})
[12:31:28.889] [bmv2] [D] [thread 31796] [15.0] [cxt 0] Pipeline 'ingress': end
[12:31:28.889] [bmv2] [T] [thread 31796] Learning sample for list id 1
[12:31:28.889] [bmv2] [D] [thread 31796] [15.0] [cxt 0] Egress port is 0
[12:31:28.889] [bmv2] [T] [thread 40586] Sending learning notification for list id 1 (buffer id 2)
[12:31:28.889] [bmv2] [D] [thread 31797] [15.0] [cxt 0] Pipeline 'egress': start
[12:31:28.889] [bmv2] [D] [thread 31797] [15.0] [cxt 0] Pipeline 'egress': end
[12:31:28.889] [bmv2] [D] [thread 31797] [15.0] [cxt 0] Deparser 'deparser': start
[12:31:28.889] [bmv2] [D] [thread 31797] [15.0] [cxt 0] Deparsing header 'ether'
[12:31:28.889] [bmv2] [D] [thread 31797] [15.0] [cxt 0] Deparser 'deparser': end
[12:31:28.889] [bmv2] [D] [thread 31801] [15.0] [cxt 0] Transmitting packet of size 42 out of port 0
```

6. Clean up

* Stop p4digest_agent and BMv2: `ctrl+c`
* Delete namespace, vtap: `sudo ./bmv2-digest-env.sh -d 1`
