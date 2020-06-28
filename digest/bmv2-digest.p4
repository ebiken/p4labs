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

// An example code to send digest to control plane via P4Runtime.
// Target: BMv2

#include <core.p4>
#include <v1model.p4>

typedef bit<48> EthernetAddress;
typedef bit<16> EthernetType;
typedef bit<9>  PortId_t; // ingress_port/egress_port in v1model

// Headers
header Ethernet_h {
    EthernetAddress dstAddr;
    EthernetAddress srcAddr;
    EthernetType etherType;
}

// Structs
struct Header {
    Ethernet_h ether;
}
struct mac_learn_digest_t {
    EthernetAddress srcAddr;
    PortId_t        ingress_port;
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
        transition parse_ethernet;
    }
    state parse_ethernet {
        pkt.extract(hdr.ether);
        transition accept;
    }
}

// Deparser
control SwitchDeparser(
            packet_out pkt,
            in Header hdr) {

    apply {
        pkt.emit(hdr.ether);
    }
}

// Control
control SwitchIngress(
            inout Header hdr,
            inout UserMetadata user_md,
            inout standard_metadata_t st_md) {
    // Action
    action send_digest() {
        digest<mac_learn_digest_t>(1, {hdr.ether.srcAddr, st_md.ingress_port});
    }

    // Table
    table digest_table {
        key = {
            st_md.ingress_port : exact;
        }
        actions = {
            send_digest;
        }
        // no need to set table entry from control plane to send digest
        const default_action = send_digest;
    }

    // Apply: <table_name>.apply();
    apply {
        digest_table.apply();
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
