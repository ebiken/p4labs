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

// Example 01: Check egress_spec and egress_port after mark_to_drop(st_md) was called.
// Target: BMv2

#include <core.p4>
#include <v1model.p4>

typedef bit<9>  PortId_t; // ingress_port/egress_port in v1model
typedef bit<48> ethernet_address_t;
typedef bit<16> ethernet_type_t;
const ethernet_type_t ETH_P_IPV4 = 16w0x0800;

// Headers
header ethernet_h {
    ethernet_address_t dst_addr;
    ethernet_address_t src_addr;
    ethernet_type_t type;
}

// Structs
struct headers_t {
    ethernet_h ethernet;
}
struct user_metadata_t {
    // place holder
}

// Parser
parser SwitchParser(
            packet_in pkt,
            out headers_t hdr,
            inout user_metadata_t user_md,
            inout standard_metadata_t st_md) {
    state start {
        transition select(st_md.ingress_port) {
            default: parse_ethernet;
        }
    }
    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition accept;
    }
}

// Deparser
control SwitchDeparser(
            packet_out pkt,
            in headers_t hdr) {
    apply {
        pkt.emit(hdr);
    }
}

// Control
control SwitchIngress(
            inout headers_t hdr,
            inout user_metadata_t user_md,
            inout standard_metadata_t st_md) {
    // Action
    action set_egress_spec() {
        st_md.egress_spec = 8; // could be any number other than 0
        st_md.mcast_grp = 8; // could be any number other than 0
    }

    // Table
    table ingress_table_1 { 
        key = {
            st_md.egress_spec: exact;
            st_md.egress_port: exact;
            st_md.mcast_grp: exact;
        }
        actions = {
            NoAction;
            set_egress_spec;
        }
        const default_action = set_egress_spec;
    }
    table ingress_table_2 {
        key = {
            st_md.egress_spec: exact;
            st_md.egress_port: exact;
            st_md.mcast_grp: exact;
        }
        actions = {
            NoAction;
            set_egress_spec;
        }
        const default_action = NoAction;
    }
    table ingress_table_3 {
        key = {
            st_md.egress_spec: exact;
            st_md.egress_port: exact;
            st_md.mcast_grp: exact;
        }
        actions = {
            NoAction;
            set_egress_spec;
        }
        const default_action = NoAction;
    }

    // Apply: <table_name>.apply();
    apply {
        ingress_table_1.apply();
        ingress_table_2.apply();
//        mark_to_drop(st_md);
        ingress_table_3.apply();
    }
}
control SwitchEgress(
            inout headers_t hdr,
            inout user_metadata_t user_md,
            inout standard_metadata_t st_md) {
    table egress_table_1 {
        key = {
            st_md.egress_spec: exact;
            st_md.egress_port: exact;
            st_md.mcast_grp: exact;
        }
        actions = {
            NoAction;
        }
        const default_action = NoAction;
    }
    apply {
        egress_table_1.apply();
    }
}
control NoSwitchVerifyChecksum(
            inout headers_t hdr,
            inout user_metadata_t user_md) {
    // dummy control to skip checkum
    apply { }
}
control NoSwitchComputeChecksum(
            inout headers_t hdr,
            inout user_metadata_t user_md) {
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
