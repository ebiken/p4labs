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

// An example code to send packet from control plane (PacketOut) via P4Runtime.
// Target: BMv2

#include <core.p4>
#include <v1model.p4>

typedef bit<48> EthernetAddress;
typedef bit<16> EthernetType;
typedef bit<9>  PortId_t; // ingress_port/egress_port in v1model

#define CPU_PORT 9w192 // using same number as PSA

// Headers
header Ethernet_h {
    EthernetAddress dstAddr;
    EthernetAddress srcAddr;
    EthernetType etherType;
}

typedef bit<16> PortIdP4Runtime_t;
#define BMV2_PORTID_TO_P4RT(p) ((PortIdP4Runtime_t)(p))
#define BMV2_PORTID_FROM_P4RT(p) ((PortId_t)(bit<32>)(p))

@controller_header("packet_out")
header PacketOut_t {
    PortIdP4Runtime_t egress_port;
}

// Structs
struct Header {
    PacketOut_t packet_out;
    Ethernet_h ether;
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
        transition accept;
    }
}

// Control
control SwitchIngress(
            inout Header hdr,
            inout UserMetadata user_md,
            inout standard_metadata_t st_md) {
    apply {
        if (hdr.packet_out.isValid()) {
            st_md.egress_spec = BMV2_PORTID_FROM_P4RT(hdr.packet_out.egress_port);
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

// Checksum
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

// Deparser
control SwitchDeparser(
            packet_out pkt,
            in Header hdr) {
    apply {
        pkt.emit(hdr.ether);
    }
}

V1Switch(SwitchParser(),
         NoSwitchVerifyChecksum(),
         SwitchIngress(),
         SwitchEgress(),
         NoSwitchComputeChecksum(),
         SwitchDeparser()
) main;
