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

// Example 02: Sending packet to both CPU and specific ports (clone)
// Target: BMv2

#include <core.p4>
#include <v1model.p4>

typedef bit<9>  PortId_t; // ingress_port/egress_port in v1model
typedef bit<48> ethernet_address_t;
typedef bit<16> ethernet_type_t;
const ethernet_type_t ETH_P_IPV4 = 16w0x0800;

// These definitions are derived from the numerical values of the enum
// named "PktInstanceType" in the p4lang/behavioral-model source file
// targets/simple_switch/simple_switch.h
// https://github.com/p4lang/behavioral-model/blob/master/targets/simple_switch/simple_switch.h#L126-L134

const bit<32> BMV2_V1MODEL_INSTANCE_TYPE_NORMAL        = 0;
const bit<32> BMV2_V1MODEL_INSTANCE_TYPE_INGRESS_CLONE = 1;
const bit<32> BMV2_V1MODEL_INSTANCE_TYPE_EGRESS_CLONE  = 2;
const bit<32> BMV2_V1MODEL_INSTANCE_TYPE_COALESCED     = 3;
const bit<32> BMV2_V1MODEL_INSTANCE_TYPE_RECIRC        = 4;
const bit<32> BMV2_V1MODEL_INSTANCE_TYPE_REPLICATION   = 5;
const bit<32> BMV2_V1MODEL_INSTANCE_TYPE_RESUBMIT      = 6;

#define IS_RESUBMITTED(st_md) (st_md.instance_type == BMV2_V1MODEL_INSTANCE_TYPE_RESUBMIT)
#define IS_RECIRCULATED(st_md) (st_md.instance_type == BMV2_V1MODEL_INSTANCE_TYPE_RECIRC)
#define IS_I2E_CLONE(st_md) (st_md.instance_type == BMV2_V1MODEL_INSTANCE_TYPE_INGRESS_CLONE)
#define IS_E2E_CLONE(st_md) (st_md.instance_type == BMV2_V1MODEL_INSTANCE_TYPE_EGRESS_CLONE)
#define IS_REPLICATED(st_md) (st_md.instance_type == BMV2_V1MODEL_INSTANCE_TYPE_REPLICATION)

const bit<32> I2E_CLONE_SESSION_ID = 0; // send to CPU_PORT
const bit<32> E2E_CLONE_SESSION_ID = 11;

// Headers
header ethernet_h {
    ethernet_address_t dst_addr;
    ethernet_address_t src_addr;
    ethernet_type_t type;
}
// Headers: PacketIn
#define CPU_PORT 9w192 // using same number as PSA
typedef bit<16> PortIdP4Runtime_t;
#define BMV2_PORTID_TO_P4RT(p) ((PortIdP4Runtime_t)(p))
#define BMV2_PORTID_FROM_P4RT(p) ((PortId_t)(bit<32>)(p))
@controller_header("packet_in")
header packet_in_h {
    //bit<9> ingress_port;
    PortIdP4Runtime_t ingress_port;
    bit<1> is_clone;
    bit<7> padding;
}

// Structs
struct headers_t {
    packet_in_h packet_in;
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
    action send_to_cpu() {
        st_md.egress_spec = CPU_PORT;
    }
    action do_clone3_i2e() {
        //st_md.egress_spec = 2;
        clone3(CloneType.I2E, I2E_CLONE_SESSION_ID, st_md);
    }

    // Table
    table ingress_table_1 { 
        key = {
            st_md.ingress_port: exact;
            st_md.instance_type: exact;
        }
        actions = {
            NoAction;
            send_to_cpu;
            do_clone3_i2e;
        }
        //const default_action = NoAction;
        //const default_action = send_to_cpu;
        const default_action = do_clone3_i2e;
    }
    // Table
    table ingress_table_2 {
        key = {
            st_md.ingress_port: exact;
            st_md.instance_type: exact;
        }
        actions = {
            NoAction;
            send_to_cpu;
            do_clone3_i2e;
        }
        const default_action = NoAction;
        //const default_action = send_to_cpu;
        //const default_action = do_clone3_i2e;
    }

    // Apply: <table_name>.apply();
    apply {
        mark_to_drop(st_md);
        ingress_table_1.apply(); // clone to CPU
        st_md.egress_spec = 2;
        ingress_table_2.apply(); // check st_md (NoAction)
    }
}
control SwitchEgress(
            inout headers_t hdr,
            inout user_metadata_t user_md,
            inout standard_metadata_t st_md) {
    // Nothing to do
    table egress_table_1 {
        key = {
            st_md.ingress_port: exact;
            st_md.instance_type: exact;
            st_md.egress_port: exact;
        }
        actions = {
            NoAction;
        }
        const default_action = NoAction;
    }
    apply {
        if (st_md.egress_port == CPU_PORT) {
            hdr.packet_in.setValid();
            hdr.packet_in.ingress_port = BMV2_PORTID_TO_P4RT(st_md.ingress_port);
            if (IS_I2E_CLONE(st_md) || IS_E2E_CLONE(st_md)) {
                hdr.packet_in.is_clone = 1;
            } else {
                hdr.packet_in.is_clone = 0;
            }
            hdr.packet_in.padding = 0;
        }
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
