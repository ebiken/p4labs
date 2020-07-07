# example: hostip

This example shows how to create Layer 3 Host Interface on P4 switch using P4Runtime API with a Golang Agent.

Packets sent to host interface on P4 switch will be forwarded by the agent and received by the host OS tap interface to resolve ARP, respond to ping etc.

## Overview (Target: BMv2)

* As a virtual host, create a netns named "host1" and attach one of the veth pair to it
* Attach another side of the veth pair to P4 switch (specify when starting simple_switch_grpc)
* GoAgent (`agent.go`), which is a P4Runtime Client, will create tap interface on host OS and assign an IPv4 address acting as Layer 3 Host Interface on P4 switch
* When sending packet from host1 to tap
    * switch will send packet to agent via PacketIn
    * agent will receive write the PacketIn packet to tap interface
* When sending packet from tap to host1
    * agent will read packet from tap interface
    * agent will send packet to switch via PacketOut
    * switch will forward packet to host1

Diagram:

```
  ns: host1     BMv2      Linux Host (kernel)
  +-------+   +------+   +----------+
  | veth1 +---+ p1   +---+ tap00    |
  +---+---+   +------+   +----------+

* veth1: 192.168.0.1/24
* tap00: 192.168.0.100/24
* p1: port#1 on BMv2 (P4 switch)
```

## Running the example (Target: BMv2)

1. Compile P4 code.

```
$ p4c --std p4_16 -b bmv2 --p4runtime-files build.bmv2/bmv2.p4info.txt -o build.bmv2 bmv2.p4
$ ls build.bmv2/
bmv2.json  bmv2.p4i  bmv2.p4info.txt
```

2. Create veth pair and assign to network namespace (netns)

* Running script to create netns and veth pair

```
$ sudo ./bmv2-env.sh -c 1

$ ip netns
host1 (id: 0)
$ ip a show p1
7: p1@if8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 3e:12:24:ed:5c:55 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::3c12:24ff:feed:5c55/64 scope link
       valid_lft forever preferred_lft forever
$ sudo ip netns exec host1 ip a show veth1
8: veth1@if7: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 02:03:04:05:06:01 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 192.168.0.1/24 scope global veth1
       valid_lft forever preferred_lft forever
 ... snip ...
```

3. Run BMv2 with P4Runtime (grpc) enabled

```
$ sudo simple_switch_grpc --no-p4 -i 1@p1 --log-console -L trace \
-- --grpc-server-addr 0.0.0.0:50051 --cpu-port 192
```

4. Run bmv2-host_agent.go

```
> prerequisits
> intall go
$ go get google.golang.org/grpc
$ go get github.com/p4lang/p4runtime/go/p4/v1
$ go get github.com/p4lang/p4runtime/go/p4/config/v1
$ go get github.com/golang/protobuf/proto
$ go get github.com/pkg/errors
$ go get github.com/vishvananda/netlink

> run 
$ sudo go run agent.go
```

As soon as you start the agent, it will show log receiving/sending packets from tap interface.

You can also see tap00 created on host by the agent.
```
$ ip a show tap00
10: tap00: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UNKNOWN group default qlen 1000
    link/ether 2a:a3:98:79:56:c2 brd ff:ff:ff:ff:ff:ff
    inet 192.168.0.100/24 brd 192.168.0.255 scope global tap00
       valid_lft forever preferred_lft forever
    inet6 fe80::28a3:98ff:fe79:56c2/64 scope link
       valid_lft forever preferred_lft forever
```

5. Ping from host1 to L3 Host Interface (tap00)

```
$ sudo ip netns exec host1 ping 192.168.0.100 -c 4
PING 192.168.0.100 (192.168.0.100) 56(84) bytes of data.
64 bytes from 192.168.0.100: icmp_seq=1 ttl=64 time=3.77 ms
64 bytes from 192.168.0.100: icmp_seq=2 ttl=64 time=2.85 ms
64 bytes from 192.168.0.100: icmp_seq=3 ttl=64 time=3.16 ms
64 bytes from 192.168.0.100: icmp_seq=4 ttl=64 time=2.80 ms
```

6. Clean up

* Stop p4digest_agent and BMv2: `ctrl+c`
* Delete namespace, vtap: `sudo ./bmv2-env.sh -d 1`

## Console log (Target: BMv2)

Agent and BMv2 console log when sending ping with command below.

```$ sudo ip netns exec host1 ping 192.168.0.100 -c 4```

* Agent

```
> host1 => tap00 (PacketIn)
2020/07/07 11:58:37 PacketIn: Packet from switch. Forwarding to tap: tap00
2020/07/07 11:58:37 | Metadata: [metadata_id:1 value:"\000\001"  metadata_id:2 value:"\000"  metadata_id:3 value:"\000" ]
2020/07/07 11:58:37 | Dst: 2a:a3:98:79:56:c2
2020/07/07 11:58:37 | Src: 02:03:04:05:06:01
2020/07/07 11:58:37 | Ethertype: 0800
2020/07/07 11:58:37 | Packet Dump:
00000000  2a a3 98 79 56 c2 02 03  04 05 06 01 08 00 45 00  |*..yV.........E.|
00000010  00 54 e7 94 40 00 40 01  d1 5e c0 a8 00 01 c0 a8  |.T..@.@..^......|
00000020  00 64 08 00 5e 84 2c bc  00 04 dd e4 03 5f 00 00  |.d..^.,......_..|
00000030  00 00 cc a4 00 00 00 00  00 00 10 11 12 13 14 15  |................|
00000040  16 17 18 19 1a 1b 1c 1d  1e 1f 20 21 22 23 24 25  |.......... !"#$%|
00000050  26 27 28 29 2a 2b 2c 2d  2e 2f 30 31 32 33 34 35  |&'()*+,-./012345|
00000060  36 37                                             |67|

> tap00 => host1 (PacketOut)
2020/07/07 11:58:37 Received Packet from vtap (len: 98)
2020/07/07 11:58:37 | Dst: 02:03:04:05:06:01
2020/07/07 11:58:37 | Src: 2a:a3:98:79:56:c2
2020/07/07 11:58:37 | Ethertype: 0800
2020/07/07 11:58:37 | Packet Dump:
00000000  02 03 04 05 06 01 2a a3  98 79 56 c2 08 00 45 00  |......*..yV...E.|
00000010  00 54 c7 0e 00 00 40 01  31 e5 c0 a8 00 64 c0 a8  |.T....@.1....d..|
00000020  00 01 00 00 66 84 2c bc  00 04 dd e4 03 5f 00 00  |....f.,......_..|
00000030  00 00 cc a4 00 00 00 00  00 00 10 11 12 13 14 15  |................|
00000040  16 17 18 19 1a 1b 1c 1d  1e 1f 20 21 22 23 24 25  |.......... !"#$%|
00000050  26 27 28 29 2a 2b 2c 2d  2e 2f 30 31 32 33 34 35  |&'()*+,-./012345|
00000060  36 37                                             |67|
2020/07/07 11:58:37 PacketOut: sending packet to port: [0 1]
```

* BMv2

```
> host1 => tap00 (PacketIn)
[12:01:11.320] [bmv2] [D] [thread 11731] [2.0] [cxt 0] Processing packet received on port 1
[12:01:11.321] [bmv2] [D] [thread 11731] [2.0] [cxt 0] Parser 'parser': start
[12:01:11.321] [bmv2] [D] [thread 11731] [2.0] [cxt 0] Parser 'parser' entering state 'start'
[12:01:11.321] [bmv2] [D] [thread 11731] [2.0] [cxt 0] Parser state 'start': key is 0001
[12:01:11.321] [bmv2] [T] [thread 11731] [2.0] [cxt 0] Bytes parsed: 0
[12:01:11.321] [bmv2] [D] [thread 11731] [2.0] [cxt 0] Parser 'parser' entering state 'parse_ethernet'
[12:01:11.321] [bmv2] [D] [thread 11731] [2.0] [cxt 0] Extracting header 'ether'
[12:01:11.321] [bmv2] [D] [thread 11731] [2.0] [cxt 0] Parser state 'parse_ethernet': key is 0800
[12:01:11.321] [bmv2] [T] [thread 11731] [2.0] [cxt 0] Bytes parsed: 14
[12:01:11.321] [bmv2] [D] [thread 11731] [2.0] [cxt 0] Parser 'parser' entering state 'parse_ipv4'
[12:01:11.321] [bmv2] [D] [thread 11731] [2.0] [cxt 0] Extracting header 'ipv4'
[12:01:11.321] [bmv2] [D] [thread 11731] [2.0] [cxt 0] Parser state 'parse_ipv4' has no switch, going to default next state
[12:01:11.321] [bmv2] [T] [thread 11731] [2.0] [cxt 0] Bytes parsed: 34
[12:01:11.321] [bmv2] [D] [thread 11731] [2.0] [cxt 0] Parser 'parser': end
[12:01:11.321] [bmv2] [D] [thread 11731] [2.0] [cxt 0] Pipeline 'ingress': start
[12:01:11.321] [bmv2] [T] [thread 11731] [2.0] [cxt 0] bmv2.p4(177) Condition "hdr.packet_out.isValid()" (node_2) is false
[12:01:11.321] [bmv2] [T] [thread 11731] [2.0] [cxt 0] Applying table 'SwitchIngress.dmac_table'
[12:01:11.321] [bmv2] [D] [thread 11731] [2.0] [cxt 0] Looking up key:
* hdr.ether.dstAddr   : 2aa3987956c2
[12:01:11.321] [bmv2] [D] [thread 11731] [2.0] [cxt 0] Table 'SwitchIngress.dmac_table': miss
[12:01:11.321] [bmv2] [D] [thread 11731] [2.0] [cxt 0] Action entry is SwitchIngress.send_to_cpu -
[12:01:11.321] [bmv2] [T] [thread 11731] [2.0] [cxt 0] Action SwitchIngress.send_to_cpu
[12:01:11.321] [bmv2] [T] [thread 11731] [2.0] [cxt 0] bmv2.p4(152) Primitive st_md.egress_spec = 9w192
[12:01:11.321] [bmv2] [T] [thread 11731] [2.0] [cxt 0] bmv2.p4(153) Primitive hdr.packet_in.setValid()
[12:01:11.321] [bmv2] [T] [thread 11731] [2.0] [cxt 0] bmv2.p4(154) Primitive hdr.packet_in.ingress_port = 1
[12:01:11.321] [bmv2] [T] [thread 11731] [2.0] [cxt 0] bmv2.p4(155) Primitive hdr.packet_in.is_clone = 0
[12:01:11.321] [bmv2] [T] [thread 11731] [2.0] [cxt 0] bmv2.p4(156) Primitive hdr.packet_in.padding = 0
[12:01:11.321] [bmv2] [D] [thread 11731] [2.0] [cxt 0] Pipeline 'ingress': end
[12:01:11.321] [bmv2] [D] [thread 11731] [2.0] [cxt 0] Egress port is 192
[12:01:11.322] [bmv2] [D] [thread 11732] [2.0] [cxt 0] Pipeline 'egress': start
[12:01:11.322] [bmv2] [D] [thread 11732] [2.0] [cxt 0] Pipeline 'egress': end
[12:01:11.322] [bmv2] [D] [thread 11732] [2.0] [cxt 0] Deparser 'deparser': start
[12:01:11.322] [bmv2] [D] [thread 11732] [2.0] [cxt 0] Deparsing header 'packet_in'
[12:01:11.322] [bmv2] [D] [thread 11732] [2.0] [cxt 0] Deparsing header 'ether'
[12:01:11.322] [bmv2] [D] [thread 11732] [2.0] [cxt 0] Deparsing header 'ipv4'
[12:01:11.322] [bmv2] [D] [thread 11732] [2.0] [cxt 0] Deparser 'deparser': end
[12:01:11.322] [bmv2] [D] [thread 11736] [2.0] [cxt 0] Transmitting packet of size 101 out of port 192
[12:01:11.322] [bmv2] [D] [thread 11736] Transmitting packet-in
PACKET IN

> tap00 => host1 (PacketOut)
PACKET OUT
[12:01:11.323] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Processing packet received on port 192
[12:01:11.323] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Parser 'parser': start
[12:01:11.323] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Parser 'parser' entering state 'start'
[12:01:11.323] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Parser state 'start': key is 00c0
[12:01:11.323] [bmv2] [T] [thread 11731] [3.0] [cxt 0] Bytes parsed: 0
[12:01:11.323] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Parser 'parser' entering state 'parse_packet_out'
[12:01:11.323] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Extracting header 'packet_out'
[12:01:11.323] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Parser state 'parse_packet_out' has no switch, going to default next state
[12:01:11.323] [bmv2] [T] [thread 11731] [3.0] [cxt 0] Bytes parsed: 2
[12:01:11.323] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Parser 'parser' entering state 'parse_ethernet'
[12:01:11.323] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Extracting header 'ether'
[12:01:11.323] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Parser state 'parse_ethernet': key is 0800
[12:01:11.323] [bmv2] [T] [thread 11731] [3.0] [cxt 0] Bytes parsed: 16
[12:01:11.323] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Parser 'parser' entering state 'parse_ipv4'
[12:01:11.323] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Extracting header 'ipv4'
[12:01:11.323] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Parser state 'parse_ipv4' has no switch, going to default next state
[12:01:11.324] [bmv2] [T] [thread 11731] [3.0] [cxt 0] Bytes parsed: 36
[12:01:11.324] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Parser 'parser': end
[12:01:11.324] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Pipeline 'ingress': start
[12:01:11.324] [bmv2] [T] [thread 11731] [3.0] [cxt 0] bmv2.p4(177) Condition "hdr.packet_out.isValid()" (node_2) is true
[12:01:11.324] [bmv2] [T] [thread 11731] [3.0] [cxt 0] Applying table 'tbl_bmv2l178'
[12:01:11.324] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Looking up key:

[12:01:11.324] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Table 'tbl_bmv2l178': miss
[12:01:11.324] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Action entry is bmv2l178 -
[12:01:11.324] [bmv2] [T] [thread 11731] [3.0] [cxt 0] Action bmv2l178
[12:01:11.324] [bmv2] [T] [thread 11731] [3.0] [cxt 0] bmv2.p4(178) Primitive st_md.egress_spec = ((PortId_t)(bit<32>)(hdr.packet_out.egress_port)
[12:01:11.324] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Pipeline 'ingress': end
[12:01:11.324] [bmv2] [D] [thread 11731] [3.0] [cxt 0] Egress port is 1
[12:01:11.324] [bmv2] [D] [thread 11733] [3.0] [cxt 0] Pipeline 'egress': start
[12:01:11.324] [bmv2] [D] [thread 11733] [3.0] [cxt 0] Pipeline 'egress': end
[12:01:11.324] [bmv2] [D] [thread 11733] [3.0] [cxt 0] Deparser 'deparser': start
[12:01:11.324] [bmv2] [D] [thread 11733] [3.0] [cxt 0] Deparsing header 'ether'
[12:01:11.324] [bmv2] [D] [thread 11733] [3.0] [cxt 0] Deparsing header 'ipv4'
[12:01:11.324] [bmv2] [D] [thread 11733] [3.0] [cxt 0] Deparser 'deparser': end
[12:01:11.324] [bmv2] [D] [thread 11736] [3.0] [cxt 0] Transmitting packet of size 98 out of port 1
```

## Notes

* PacketIn => StreamMessageResponse, PacketOut => StreamMessageRequest

```
./go/src/github.com/p4lang/p4runtime/go/p4/v1/p4runtime.pb.go

$ grep PacketIn * | grep StreamMessage
p4runtime.pb.go:func (m *StreamMessageResponse) GetPacket() *PacketIn {

$ grep PacketOut * | grep StreamMessage
p4runtime.pb.go:func (m *StreamMessageRequest) GetPacket() *PacketOut {
```

* p4runtime.proto: PacketIn / PacketOut definition

```
// Packet sent from the controller to the switch.
message PacketOut {
  bytes payload = 1;
  // This will be based on P4 header annotated as
  // @controller_header("packet_out").
  // At most one P4 header can have this annotation.
  repeated PacketMetadata metadata = 2;
}

// Packet sent from the switch to the controller.
message PacketIn {
  bytes payload = 1;
  // This will be based on P4 header annotated as
  // @controller_header("packet_in").
  // At most one P4 header can have this annotation.
  repeated PacketMetadata metadata = 2;
}
```

* p4runtime.pb.go: PacketIn definition

```
> p4runtime.pb.go
3111 // Packet sent from the switch to the controller.
3112 type PacketIn struct {
3113     Payload []byte `protobuf:"bytes,1,opt,name=payload,proto3" json:"payload,omitempty"`
3114     // This will be based on P4 header annotated as
3115     // @controller_header("packet_in").
3116     // At most one P4 header can have this annotation.
3117     Metadata             []*PacketMetadata `protobuf:"bytes,2,rep,name=metadata,proto3" json:"metadata,omitempty"`
3118     XXX_NoUnkeyedLiteral struct{}          `json:"-"`
3119     XXX_unrecognized     []byte            `json:"-"`
3120     XXX_sizecache        int32             `json:"-"`
3121 }

3064 func (m *StreamMessageResponse) GetPacket() *PacketIn {
3065     if x, ok := m.GetUpdate().(*StreamMessageResponse_Packet); ok {
3066         return x.Packet
3067     }
3068     return nil
3069 }

3018 type StreamMessageResponse_Packet struct {
3019     Packet *PacketIn `protobuf:"bytes,2,opt,name=packet,proto3,oneof"`
3020 }
```
