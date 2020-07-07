/*
 * Copyright 2020 Toyota Motor Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Kentaro Ebisawa <ebisawa@toyota-tokyo.tech>
 *
 */

// An example code to use Host OS Interface as Switch L3 host interface.
// Target: BMv2

#include <core.p4>
#include <v1model.p4>

typedef bit<9>  PortId_t; // ingress_port/egress_port in v1model
typedef bit<48> EthernetAddress;
typedef bit<32> IPv4Address;
typedef bit<128> IPv6Address;
typedef bit<8> IPProtocol;
typedef bit<16> EthernetType;
const EthernetType ETH_P_IPV4 = 16w0x0800;
const EthernetType ETH_P_IPV6 = 16w0x86dd;

// Headers: PacketIn/PacketOut
#define CPU_PORT 9w192 // using same number as PSA
typedef bit<16> PortIdP4Runtime_t;
#define BMV2_PORTID_TO_P4RT(p) ((PortIdP4Runtime_t)(p))
#define BMV2_PORTID_FROM_P4RT(p) ((PortId_t)(bit<32>)(p))
@controller_header("packet_out")
header PacketOut_h {
    PortIdP4Runtime_t egress_port;
}
@controller_header("packet_in")
header PacketIn_h {
    //bit<9> ingress_port;
    PortIdP4Runtime_t ingress_port;
    bit<1> is_clone;
    bit<7> padding;
}

// Headers
header Ethernet_h {
    EthernetAddress dstAddr;
    EthernetAddress srcAddr;
    EthernetType etherType;
}

header IPv4_h {
    bit<4> version;
    bit<4> ihl;
    bit<8> diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3> flags;
    bit<13> fragOffset;
    bit<8> ttl;
    IPProtocol protocol;
    bit<16> hdrChecksum;
    IPv4Address srcAddr;
    IPv4Address dstAddr;
}

header IPv6_h {
    bit<4> version;
    bit<8> trafficClass;
    bit<20> flowLabel;
    bit<16> payloadLen;
    bit<8> nextHdr;
    bit<8> hopLimit;
    IPv6Address srcAddr;
    IPv6Address dstAddr;
}

// Structs
struct Header {
    PacketOut_h packet_out;
    PacketIn_h packet_in;
    Ethernet_h ether;
    IPv6_h ipv6;
    IPv4_h ipv4;
}
struct UserMetadata {
    // place holder
}

// Parser
parser SwitchParser(
            packet_in pkt,
            out Header hdr,
            inout UserMetadata user_md,
            inout standard_metadata_t st_md) {
    state start {
        transition select(st_md.ingress_port) {
            CPU_PORT: parse_packet_out;
            default: parse_ethernet;
        }
    }
    state parse_packet_out{
        pkt.extract(hdr.packet_out);
        transition parse_ethernet;
    }
    state parse_ethernet {
        pkt.extract(hdr.ether);
        transition select(hdr.ether.etherType) {
            ETH_P_IPV4 : parse_ipv4;
            ETH_P_IPV6 : parse_ipv6;
            default : accept;
        }
    }
    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition accept;
    }
    state parse_ipv6 {
        pkt.extract(hdr.ipv6);
        transition accept;
    }
}

// Deparser
control SwitchDeparser(
            packet_out pkt,
            in Header hdr) {

    apply {
        // pkt.emit(hdr.packet_out); // not required
        pkt.emit(hdr.packet_in);
        pkt.emit(hdr.ether);
        pkt.emit(hdr.ipv4);
        pkt.emit(hdr.ipv6);
    }
}

// Control
control SwitchIngress(
            inout Header hdr,
            inout UserMetadata user_md,
            inout standard_metadata_t st_md) {
    // Action
    action send_to_cpu() {
        st_md.egress_spec = CPU_PORT;
        hdr.packet_in.setValid();
        hdr.packet_in.ingress_port = 1;
        hdr.packet_in.is_clone = 0;
        hdr.packet_in.padding = 0;
    }

    // Table
    // To simply test host interface, this table is used to send all packets
    // to the host CPU. When building real L3 switch, you should just send
    // packet with multicast/broadcast dmac or both dmac/IP dstAddr match
    // host interface.
    table dmac_table { 
        key = {
            hdr.ether.dstAddr : exact;
        }
        actions = {
            NoAction;
            send_to_cpu;
        }
        const default_action = send_to_cpu;
    }

    // Apply: <table_name>.apply();
    apply {
        if (hdr.packet_out.isValid()) {
            st_md.egress_spec = BMV2_PORTID_FROM_P4RT(hdr.packet_out.egress_port);
        } else {
            // TODO: replace with hostmac(multi/broadcast), hostipv4, hostipv6 table
            dmac_table.apply();
        }
    }
}
control SwitchEgress(
            inout Header hdr,
            inout UserMetadata user_md,
            inout standard_metadata_t st_md) {
    // nothing to do
    apply { }
}
control NoSwitchVerifyChecksum(
            inout Header hdr,
            inout UserMetadata user_md) {
    // dummy control to skip checkum
    apply { }
}
control NoSwitchComputeChecksum(
            inout Header hdr,
            inout UserMetadata user_md) {
    // dummy control to skip checkum
    apply { }
}
V1Switch(SwitchParser(),
         NoSwitchVerifyChecksum(),
         SwitchIngress(),
         SwitchEgress(),
         NoSwitchComputeChecksum(),
         SwitchDeparser()
) main;
