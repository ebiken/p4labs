# example: packetout

How to send packet to switch from a Golang Control Plane agent (PacketOut) via P4Runtime.

## Target BMv2

1. Compile P4 code.

```
$ p4c --std p4_16 -b bmv2 --p4runtime-files build.bmv2/bmv2.p4info.txt -o build.bmv2 bmv2.p4
$ ls build.bmv2/
bmv2.json  bmv2.p4i  bmv2.p4info.txt
```

2. Create vtap pair and assign to a namespace (vhost)

```
$ sudo ./bmv2-env.sh -c 1

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
-- --grpc-server-addr 0.0.0.0:50051 --cpu-port 192

Calling target program-options parser
Adding interface vtap1 as port 1
[17:20:05.639] [bmv2] [D] [thread 15080] Adding interface vtap1 as port 1
Server listening on 0.0.0.0:50051
[17:20:05.670] [bmv2] [I] [thread 15080] Starting Thrift server on port 9090
[17:20:05.671] [bmv2] [I] [thread 15080] Thrift server was started
```

4. Start packet capture on vtap1

```
$ sudo tcpdump -i vtap1 -vvv -xxx
tcpdump: listening on vtap1, link-type EN10MB (Ethernet), capture size 262144 bytes
```

5. Send Packet by running the Control Plane agent

```
> prerequisits
> intall go
$ go get google.golang.org/grpc
$ go get github.com/p4lang/p4runtime/go/p4/v1
$ go get github.com/p4lang/p4runtime/go/p4/config/v1
$ go get github.com/golang/protobuf/proto
$ go get github.com/pkg/errors

> run agent to send packet out
$ go run bmv2-agent.go
```

tcpdump output
```
17:21:22.847923 ARP, Ethernet (len 6), IPv4 (len 4), Request who-has 172.20.0.241 tell 172.20.0.240, length 28
        0x0000:  ffff ffff ffff 0203 0405 06f0 0806 0001
        0x0010:  0800 0604 0001 0203 0405 06f0 ac14 00f0
        0x0020:  0000 0000 0000 ac14 00f1
```

Agent console log
```
2020/07/04 17:21:22 p4info file: ./build.bmv2/bmv2.p4info.txt
2020/07/04 17:21:22 BMv2 device config file: ./build.bmv2/bmv2.json
2020/07/04 17:21:22 gRPC addr: 127.0.0.1:50051
2020/07/04 17:21:22 P4RuntimeClinet P4Digest(): start
2020/07/04 17:21:22 gRPC connection sucess
2020/07/04 17:21:22 | NewP4RuntimeClient: created
2020/07/04 17:21:22 masterArbitrationUpdate: election_id:<low:1 > status:<message:"Is master" >
2020/07/04 17:21:22 | masterArbitrationUpdate done
2020/07/04 17:21:22 devconfig len9063
2020/07/04 17:21:22 SetForwardingPipelineConfig:
2020/07/04 17:21:22 | result:&v1.SetForwardingPipelineConfigResponse{XXX_NoUnkeyedLiteral:struct {}{}, XXX_unrecognized:[]uint8(nil), XXX_sizecache:0}
2020/07/04 17:21:22 | error::<nil>
2020/07/04 17:21:22 | setForwardPipelineConfig done
2020/07/04 17:21:22 | P4RuntimeClinet Init: done
2020/07/04 17:21:22 PacketOut packet: {[255 255 255 255 255 255 2 3 4 5 6 240 8 6 0 1 8 0 6 4 0 1 2 3 4 5 6 240 172 20 0 240 0 0 0 0 0 0 172 20 0 241] [metadata_id:1 value:"\000\001" ] {} [] 0}
2020/07/04 17:21:23 End of main()
```

BMv2 console log
```
New connection
P4Runtime SetForwardingPipelineConfig
[17:21:22.743] [bmv2] [D] [thread 15323] Set default default entry for table 'tbl_bmv2l86': bmv2l86 -
PACKET OUT
[17:21:22.846] [bmv2] [D] [thread 15339] [0.0] [cxt 0] Processing packet received on port 192
[17:21:22.846] [bmv2] [D] [thread 15339] [0.0] [cxt 0] Parser 'parser': start
[17:21:22.846] [bmv2] [D] [thread 15339] [0.0] [cxt 0] Parser 'parser' entering state 'start'
[17:21:22.846] [bmv2] [D] [thread 15339] [0.0] [cxt 0] Parser state 'start': key is 00c0
[17:21:22.846] [bmv2] [T] [thread 15339] [0.0] [cxt 0] Bytes parsed: 0
[17:21:22.846] [bmv2] [D] [thread 15339] [0.0] [cxt 0] Parser 'parser' entering state 'parse_packet_out'
[17:21:22.846] [bmv2] [D] [thread 15339] [0.0] [cxt 0] Extracting header 'packet_out'
[17:21:22.846] [bmv2] [D] [thread 15339] [0.0] [cxt 0] Parser state 'parse_packet_out' has no switch, going to default next state
[17:21:22.846] [bmv2] [T] [thread 15339] [0.0] [cxt 0] Bytes parsed: 2
[17:21:22.846] [bmv2] [D] [thread 15339] [0.0] [cxt 0] Parser 'parser' entering state 'parse_ethernet'
[17:21:22.846] [bmv2] [D] [thread 15339] [0.0] [cxt 0] Extracting header 'ether'
[17:21:22.846] [bmv2] [D] [thread 15339] [0.0] [cxt 0] Parser state 'parse_ethernet' has no switch, going to default next state
[17:21:22.847] [bmv2] [T] [thread 15339] [0.0] [cxt 0] Bytes parsed: 16
[17:21:22.847] [bmv2] [D] [thread 15339] [0.0] [cxt 0] Parser 'parser': end
[17:21:22.847] [bmv2] [D] [thread 15339] [0.0] [cxt 0] Pipeline 'ingress': start
[17:21:22.847] [bmv2] [T] [thread 15339] [0.0] [cxt 0] bmv2.p4(85) Condition "hdr.packet_out.isValid()" (node_2) is true
[17:21:22.847] [bmv2] [T] [thread 15339] [0.0] [cxt 0] Applying table 'tbl_bmv2l86'
[17:21:22.847] [bmv2] [D] [thread 15339] [0.0] [cxt 0] Looking up key:

[17:21:22.847] [bmv2] [D] [thread 15339] [0.0] [cxt 0] Table 'tbl_bmv2l86': miss
[17:21:22.847] [bmv2] [D] [thread 15339] [0.0] [cxt 0] Action entry is bmv2l86 -
[17:21:22.847] [bmv2] [T] [thread 15339] [0.0] [cxt 0] Action bmv2l86
[17:21:22.847] [bmv2] [T] [thread 15339] [0.0] [cxt 0] bmv2.p4(86) Primitive st_md.egress_spec = ((PortId_t)(bit<32>)(hdr.packet_out.egress_port)
[17:21:22.847] [bmv2] [D] [thread 15339] [0.0] [cxt 0] Pipeline 'ingress': end
[17:21:22.847] [bmv2] [D] [thread 15339] [0.0] [cxt 0] Egress port is 1
[17:21:22.847] [bmv2] [D] [thread 15341] [0.0] [cxt 0] Pipeline 'egress': start
[17:21:22.847] [bmv2] [D] [thread 15341] [0.0] [cxt 0] Pipeline 'egress': end
[17:21:22.847] [bmv2] [D] [thread 15341] [0.0] [cxt 0] Deparser 'deparser': start
[17:21:22.847] [bmv2] [D] [thread 15341] [0.0] [cxt 0] Deparsing header 'ether'
[17:21:22.847] [bmv2] [D] [thread 15341] [0.0] [cxt 0] Deparser 'deparser': end
[17:21:22.847] [bmv2] [D] [thread 15344] [0.0] [cxt 0] Transmitting packet of size 42 out of port 1
Connection removed
```

6. Clean up

* Stop BMv2: `ctrl+c`
* Delete namespace, vtap: `sudo ./bmv2-env.sh -d 1`

## Notes

To send PacketOut from the control plane agent (P4Runtime Client)

* P4 switch: define `header PacketOut_t { PortIdP4Runtime_t egress_port; }` annotated by `@controller_header("packet_out")`
    * This will be the `Metadata` set by the P4Runtime client
    * It'll be included in the very first part of the packet
* agent: create `type PacketOut struct` with `Payload` and `Metadata`
    * `Payload` is the Ethernet packet you want to send to the switch
    * `Metadata` with `MetadataId == 1` will inculde `PortIdP4Runtime_t egress_port` which you defined in P4 code
* agent: send `StreamMessageRequest` with `PacketOut` inside the `StreamMessageRequest_Packet` message
* P4 switch: parse the PacketOut_t header and set egress_spec (outgoing port) based on the egress_port in the header

Refer to [p4runtime.pb.go](https://github.com/p4lang/p4runtime/blob/master/go/p4/v1/p4runtime.pb.go) for the auto generated Golang code for the types mentioned above.

```
type StreamMessageRequest_Packet struct {
	Packet *PacketOut `protobuf:"bytes,2,opt,name=packet,proto3,oneof"`
}

// Packet sent from the controller to the switch.
type PacketOut struct {
    Payload []byte `protobuf:"bytes,1,opt,name=payload,proto3" json:"payload,omitempty"`
    // This will be based on P4 header annotated as
    // @controller_header("packet_out").
    // At most one P4 header can have this annotation.
    Metadata             []*PacketMetadata `protobuf:"bytes,2,rep,name=metadata,proto3" json:"metadata,omitempty"`
    XXX_NoUnkeyedLiteral struct{}          `json:"-"`
    XXX_unrecognized     []byte            `json:"-"`
    XXX_sizecache        int32             `json:"-"`
}

type PacketMetadata struct {
    // This refers to Metadata.id coming from P4Info ControllerPacketMetadata.
    MetadataId           uint32   `protobuf:"varint,1,opt,name=metadata_id,json=metadataId,proto3" json:"metadata_id,omitempty"`
    Value                []byte   `protobuf:"bytes,2,opt,name=value,proto3" json:"value,omitempty"`
    XXX_NoUnkeyedLiteral struct{} `json:"-"`
    XXX_unrecognized     []byte   `json:"-"`
    XXX_sizecache        int32    `json:"-"`
}
```
