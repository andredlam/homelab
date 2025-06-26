# ovs-ofctl - OpenFlow Control Utility

**ovs-ofctl** is a command-line utility that provides a direct interface to OpenFlow switches managed by Open vSwitch (OVS). It's one of the most important tools for managing, debugging, and monitoring OVS bridges and their flow tables.

## Table of Contents

1. [What is ovs-ofctl?](#what-is-ovs-ofctl)
2. [Key Functions](#key-functions)
3. [Flow Table Management](#flow-table-management)
4. [Switch Information and Statistics](#switch-information-and-statistics)
5. [Debugging and Monitoring](#debugging-and-monitoring)
6. [OVN Integration](#ovn-integration)
7. [Common Commands Reference](#common-commands-reference)
8. [Practical Examples](#practical-examples)
9. [Advanced Usage](#advanced-usage)
10. [Troubleshooting with ovs-ofctl](#troubleshooting-with-ovs-ofctl)
11. [Best Practices](#best-practices)

## What is ovs-ofctl?

**ovs-ofctl** (Open vSwitch OpenFlow Control) is a utility that:

1. **Manages OpenFlow Rules**: Add, modify, delete, and view flow entries
2. **Monitors Switch State**: Check port status, statistics, and configuration
3. **Debugs Network Issues**: Inspect packet processing and flow matching
4. **Controls Switch Behavior**: Modify switch configuration and behavior
5. **Interfaces with Controllers**: Communicate with OpenFlow controllers

### Architecture Context
```bash
┌─────────────────────────────────────────────────────────┐
│                  OVN Control Plane                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │  Northbound │  │ ovn-northd  │  │   Southbound    │  │
│  │  Database   │  │             │  │   Database      │  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
└─────────────────────┬───────────────────────────────────┘
                      │ Logical Flows
┌─────────────────────┼────────────────────────────────────┐
│                     ▼                                    │
│  ┌──────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │ovn-controller│  │    OVS      │  │   ovs-ofctl     │  │
│  │              │◄─┤  (br-int)   │◄─┤  (Management)   │  │
│  │              │  │             │  │                 │  │
│  └──────────────┘  └─────────────┘  └─────────────────┘  │
│                   Compute Node / Chassis                 │
│ (Chassis Name / Compute Node ID / Worker Node / Hypervisor Instance ID) │
└──────────────────────────────────────────────────────────┘
```

### OpenFlow Pipeline Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              OPENFLOW PACKET PROCESSING PIPELINE                                │
│                                                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                                PACKET ARRIVAL                                            │   │
│  │                                                                                          │   │
│  │  Packet arrives → [Physical Port] → [OVS br-int] → [Table 0]                             │   │
│  │                                                                                          │   │
│  │  ┌───────────────┐     ┌─────────────────┐     ┌─────────────────┐                       │   │
│  │  │ Physical Port │────►│ Virtual Switch  │────►│ Flow Table 0    │                       │   │
│  │  │ (eth0, tap1)  │     │ (br-int/br-ex)  │     │ (Classification)│                       │   │
│  │  └───────────────┘     └─────────────────┘     └─────────────────┘                       │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                │                                                │
│                                                ▼                                                │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                              FLOW TABLE PROCESSING                                       │   │
│  │                                                                                          │   │
│  │  Table 0      Table 10     Table 20     Table 40     Table 60     Table 65               │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐            │   │
│  │  │Classify │  │Port Sec │  │ACL In   │  │L2 Learn │  │L3 Route │  │Output   │            │   │
│  │  │& Learn  │─►│& DHCP   │─►│& Policy │─►│& Switch │─►│& SNAT   │─►│Actions  │            │   │
│  │  │         │  │Opts     │  │Rules    │  │Flood    │  │& DNAT   │  │         │            │   │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘  └─────────┘  └─────────┘            │   │
│  │      │             │            │            │            │            │                 │   │
│  │      │             │            │            │            │            │                 │   │
│  │  ┌───▼─────────────▼────────────▼────────────▼────────────▼────────────▼─────────────┐   │   │
│  │  │                         MATCH CRITERIA                                            │   │   │
│  │  │                                                                                   │   │   │
│  │  │ • in_port        • dl_src/dl_dst     • nw_src/nw_dst    • tp_src/tp_dst           │   │   │
│  │  │ • tunnel_key     • dl_vlan           • nw_proto         • metadata                │   │   │
│  │  │ • reg0-reg15     • eth_type          • nw_tos           • connection state        │   │   │
│  │  └───────────────────────────────────────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                │                                                │
│                                                ▼                                                │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                  ACTIONS                                                │    │
│  │                                                                                         │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │    │
│  │  │   Output    │  │   Modify    │  │   Tunnel    │  │   Learning  │  │   Control   │    │    │
│  │  │             │  │             │  │             │  │             │  │             │    │    │
│  │  │• output:1   │  │• mod_dl_src │  │• set_tunnel │  │• learn()    │  │• controller │    │    │
│  │  │• normal     │  │• mod_nw_dst │  │• tunnel_key │  │• resubmit() │  │• drop       │    │    │
│  │  │• flood      │  │• mod_vlan   │  │• geneve     │  │• goto_table │  │• group:N    │    │    │
│  │  │• all        │  │• strip_vlan │  │• vxlan      │  │• note       │  │• meter:N    │    │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                                │                                                │
│                                                ▼                                                │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                              PACKET OUTPUT                                               │   │
│  │                                                                                          │   │
│  │  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐             │   │
│  │  │ Physical    │     │ Tunnel      │     │ Local Port  │     │ Controller  │             │   │
│  │  │ Port        │     │ Interface   │     │ (tap/veth)  │     │ (Punt)      │             │   │
│  │  │ (eth0)      │     │ (geneve)    │     │ (VM NIC)    │     │ (CPU)       │             │   │
│  │  └─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘             │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Flow Table Structure and Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                OVS FLOW TABLE HIERARCHY                                         │
│                                                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                              TABLE STRUCTURE                                             │   │
│  │                                                                                          │   │
│  │ Table 0: Classification & Learning                                                       │   │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐     │   │
│  │  │ Priority 32768: in_port=1,vlan_tci=0x0000,actions=mod_vlan_vid:1,resubmit(,1)   │     │   │
│  │  │ Priority 32767: in_port=2,vlan_tci=0x0000,actions=mod_vlan_vid:2,resubmit(,1)   │     │   │
│  │  │ Priority 0: actions=drop                                                        │     │   │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘     │   │
│  │                                        │                                                 │   │
│  │                                        ▼                                                 │   │
│  │ Table 1: VLAN Input Processing                                                           │   │
│  │  ┌───────────────────────────────────────────────────────────────────────────────────┐   │   │
│  │  │ Priority 99: dl_vlan=1,actions=strip_vlan,resubmit(,2)                            │   │   │
│  │  │ Priority 99: dl_vlan=2,actions=strip_vlan,resubmit(,2)                            │   │   │
│  │  │ Priority 0: actions=drop                                                          │   │   │
│  │  └───────────────────────────────────────────────────────────────────────────────────┘   │   │
│  │                                        │                                                 │   │
│  │                                        ▼                                                 │   │
│  │ Table 2: MAC Learning                                                                    │   │
│  │  ┌───────────────────────────────────────────────────────────────────────────────────┐   │   │
│  │  │ Priority 50: table=2,dl_src=52:54:00:12:34:56,actions=learn(...),resubmit(,3)     │   │   │
│  │  │ Priority 50: table=2,dl_src=52:54:00:12:34:57,actions=learn(...),resubmit(,3)     │   │   │
│  │  │ Priority 0: actions=flood,resubmit(,3)                                            │   │   │
│  │  └───────────────────────────────────────────────────────────────────────────────────┘   │   │
│  │                                        │                                                 │   │
│  │                                        ▼                                                 │   │
│  │ Table 3: MAC Forwarding                                                                  │   │
│  │  ┌───────────────────────────────────────────────────────────────────────────────────┐   │   │
│  │  │ Priority 50: dl_dst=52:54:00:12:34:56,actions=output:1                            │   │   │
│  │  │ Priority 50: dl_dst=52:54:00:12:34:57,actions=output:2                            │   │   │
│  │  │ Priority 0: actions=flood                                                         │   │   │
│  │  └───────────────────────────────────────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                              OVN LOGICAL TABLES                                          │   │
│  │                            (Translated to OpenFlow)                                      │   │
│  │                                                                                          │   │
│  │ Table 0-15:  Logical Ingress Pipeline                                                    │   │
│  │  ┌───────────────────────────────────────────────────────────────────────────────────┐   │   │
│  │  │ Table 0:  ls_in_port_sec_l2    (L2 port security)                                 │   │   │
│  │  │ Table 1:  ls_in_port_sec_ip    (IP port security)                                 │   │   │
│  │  │ Table 2:  ls_in_port_sec_nd    (IPv6 ND security)                                 │   │   │
│  │  │ Table 3:  ls_in_lookup_fdb     (FDB lookup)                                       │   │   │
│  │  │ Table 4:  ls_in_put_fdb        (FDB learning)                                     │   │   │
│  │  │ Table 5:  ls_in_pre_acl        (Pre-ACL processing)                               │   │   │
│  │  │ Table 6:  ls_in_pre_lb         (Pre-load balancing)                               │   │   │
│  │  │ Table 7:  ls_in_pre_stateful   (Pre-stateful processing)                          │   │   │
│  │  │ Table 8:  ls_in_acl_hint       (ACL hints)                                        │   │   │
│  │  │ Table 9:  ls_in_acl            (ACL evaluation)                                   │   │   │
│  │  │ Table 10: ls_in_qos_mark       (QoS marking)                                      │   │   │
│  │  │ Table 11: ls_in_qos_meter      (QoS metering)                                     │   │   │
│  │  │ Table 12: ls_in_lb             (Load balancing)                                   │   │   │
│  │  │ Table 13: ls_in_stateful       (Stateful processing)                              │   │   │
│  │  │ Table 14: ls_in_pre_hairpin    (Pre-hairpin processing)                           │   │   │
│  │  │ Table 15: ls_in_nat_hairpin    (NAT hairpin processing)                           │   │   │
│  │  │ Table 16: ls_in_hairpin        (Hairpin processing)                               │   │   │
│  │  │ Table 17: ls_in_arp_rsp        (ARP/ND responder)                                 │   │   │
│  │  │ Table 18: ls_in_dhcp_options   (DHCP options)                                     │   │   │
│  │  │ Table 19: ls_in_dhcp_response  (DHCP response)                                    │   │   │
│  │  │ Table 20: ls_in_dns_lookup     (DNS lookup)                                       │   │   │
│  │  │ Table 21: ls_in_dns_response   (DNS response)                                     │   │   │
│  │  │ Table 22: ls_in_external_port  (External port processing)                         │   │   │
│  │  │ Table 23: ls_in_l2_lkup        (L2 lookup)                                        │   │   │
│  │  └───────────────────────────────────────────────────────────────────────────────────┘   │   │
│  │                                        │                                                 │   │
│  │                                        ▼                                                 │   │
│  │ Table 32-47: Logical Egress Pipeline                                                     │   │
│  │  ┌───────────────────────────────────────────────────────────────────────────────────┐   │   │
│  │  │ Table 32: ls_out_pre_lb        (Pre-load balancing)                               │   │   │
│  │  │ Table 33: ls_out_pre_acl       (Pre-ACL processing)                               │   │   │
│  │  │ Table 34: ls_out_pre_stateful  (Pre-stateful processing)                          │   │   │
│  │  │ Table 35: ls_out_lb            (Load balancing)                                   │   │   │
│  │  │ Table 36: ls_out_acl_hint      (ACL hints)                                        │   │   │
│  │  │ Table 37: ls_out_acl           (ACL evaluation)                                   │   │   │
│  │  │ Table 38: ls_out_qos_mark      (QoS marking)                                      │   │   │
│  │  │ Table 39: ls_out_qos_meter     (QoS metering)                                     │   │   │
│  │  │ Table 40: ls_out_stateful      (Stateful processing)                              │   │   │
│  │  │ Table 41: ls_out_port_sec_ip   (IP port security)                                 │   │   │
│  │  │ Table 42: ls_out_port_sec_l2   (L2 port security)                                 │   │   │
│  │  │ Table 43: ls_out_check_port_sec (Port security check)                             │   │   │
│  │  └───────────────────────────────────────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Key Functions

### **1. Flow Table Management**
- View, add, modify, and delete OpenFlow rules
- Manage flow priorities and actions
- Handle flow timeouts and statistics

### **2. Switch Monitoring**
- Monitor port status and statistics
- Track flow table utilization
- Collect performance metrics

### **3. Debugging Interface**
- Trace packet paths through flow tables
- Inspect flow matching behavior
- Monitor real-time flow changes

### **4. Administrative Control**
- Configure switch features
- Manage port configurations
- Control OpenFlow protocol behavior

## Flow Table Management

### Packet Flow Through OpenFlow Tables

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              PACKET PROCESSING FLOW DIAGRAM                                     │
│                                                                                                 │
│  Packet In ───────────────────────────────────────────────────────────────────────────────────┐ │
│      │                                                                                        │ │
│      ▼                                                                                        │ │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐ │ │
│  │                              TABLE 0: CLASSIFICATION                                     │ │ │
│  │                                                                                          │ │ │
│  │  Flow Matching Process:                                                                  │ │ │
│  │  ┌───────────────────────────────────────────────────────────────────────────────────┐   │ │ │
│  │  │ 1. Check in_port (physical/virtual port where packet arrived)                     │   │ │ │
│  │  │ 2. Parse Ethernet header (src/dst MAC, VLAN tags, EtherType)                      │   │ │ │
│  │  │ 3. Parse IP header if present (src/dst IP, protocol, ToS)                         │   │ │ │
│  │  │ 4. Parse L4 header if present (src/dst port, TCP flags)                           │   │ │ │
│  │  │ 5. Extract metadata (tunnel ID, VLAN, registers)                                  │   │ │ │
│  │  └───────────────────────────────────────────────────────────────────────────────────┘   │ │ │
│  │                                           │                                              │ │ │
│  │  High Priority Match (32768) ─────────────┤                                              │ │ │
│  │  Medium Priority Match (1000) ────────────┤                                              │ │ │
│  │  Low Priority Match (100) ────────────────┤                                              │ │ │
│  │  Default Match (0) ───────────────────────┤                                              │ │ │
│  │                                           │                                              │ │ │
│  │  Actions: [mod_vlan_vid:100, resubmit(,1)]                                               │ │ │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘ │ │
│                                            │                                                  │ │
│                                            ▼                                                  │ │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐ │ │
│  │                              TABLE 1: PORT SECURITY                                      │ │ │
│  │                                                                                          │ │ │
│  │  Security Checks:                                                                        │ │ │
│  │  ┌───────────────────────────────────────────────────────────────────────────────────┐   │ │ │
│  │  │ 1. Source MAC validation (anti-spoofing)                                          │   │ │ │
│  │  │ 2. Source IP validation (if IP security enabled)                                  │   │ │ │
│  │  │ 3. DHCP option validation                                                         │   │ │ │
│  │  │ 4. Rate limiting enforcement                                                      │   │ │ │
│  │  └───────────────────────────────────────────────────────────────────────────────────┘   │ │ │
│  │                                          │                                               │ │ │
│  │  ✅ Security Pass ────────────────────────┼──► Actions: [resubmit(,2)]                  │ │ │
│  │  ❌ Security Fail ────────────────────────┼──► Actions: [drop]                          │ │ │
│  └───────────────────────────────────────────────────────────────────────────── ────────────┘ │ │
│                                            │                                                  │ │
│                                            ▼                                                  │ │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐ │ │
│  │                              TABLE 2: ACL PROCESSING                                     │ │ │
│  │                                                                                          │ │ │
│  │  Access Control:                                                                         │ │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐     │ │ │
│  │  │ Rule Priority    Match Criteria           Action                                │     │ │ │
│  │  │ ─────────────────────────────────────────────────────────────────────────────   │     │ │ │
│  │  │ 2000            tcp,tp_dst=22            drop                                   │     │ │ │
│  │  │ 1500            tcp,tp_dst=80            allow→resubmit(,3)                     │     │ │ │
│  │  │ 1000            tcp,tp_dst=443           allow→resubmit(,3)                     │     │ │ │
│  │  │ 100             icmp                     allow→resubmit(,3)                     │     │ │ │
│  │  │ 0               any                      drop                                   │     │ │ │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘     │ │ │
│  │                                          │                                               │ │ │
│  │  Flow Match ──────────────────────────────┼──► Action Execution                          │ │ │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘ │ │
│                                            │                                                  │ │
│                                            ▼                                                  │ │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐ │ │
│  │                              TABLE 3: L2 LEARNING                                        │ │ │
│  │                                                                                          │ │ │
│  │  MAC Learning Process:                                                                   │ │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐     │ │ │
│  │  │ 1. Extract source MAC from packet                                               │     │ │ │
│  │  │ 2. Check if MAC already learned for this port                                   │     │ │ │
│  │  │ 3. If new, install learning flow:                                               │     │ │ │
│  │  │    learn(table=4,priority=1000,                                                 │     │ │ │
│  │  │          NXM_OF_ETH_DST[]=NXM_OF_ETH_SRC[],                                     │     │ │ │
│  │  │          output:NXM_OF_IN_PORT[])                                               │     │ │ │
│  │  │ 4. Forward packet based on destination MAC                                      │     │ │ │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘     │ │ │
│  │                                          │                                               │ │ │
│  │  Known Destination ───────────────────────┼──► output:specific_port                      │ │ │
│  │  Unknown Destination ─────────────────────┼──► flood (broadcast to all ports)            │ │ │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘ │ │
│                                            │                                                  │ │
│                                            ▼                                                  │ │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐ │ │
│  │                              TABLE 4: FORWARDING                                         │ │ │
│  │                                                                                          │ │ │
│  │  Output Actions:                                                                         │ │ │
│  │  ┌───────────────────────────────────────────────────────────────────────────────────┐   │ │ │
│  │  │ • output:1         - Send to physical port 1                                      │   │ │ │
│  │  │ • output:2         - Send to physical port 2                                      │   │ │ │
│  │  │ • output:LOCAL     - Send to local stack                                          │   │ │ │
│  │  │ • normal           - Use normal L2/L3 processing                                  │   │ │ │
│  │  │ • flood            - Broadcast to all ports except input                          │   │ │ │
│  │  │ • drop             - Discard packet                                               │   │ │ │
│  │  │ • controller       - Send to OpenFlow controller                                  │   │ │ │
│  │  │ • group:N          - Send to load balancing group N                               │   │ │ │
│  │  └───────────────────────────────────────────────────────────────────────────────────┘   │ │ │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘ │ │
│                                            │                                                  │ │
│                                            ▼                                                  │ │
│  Packet Out ──────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                  FLOW STATISTICS                                        │    │
│  │                                                                                         │    │
│  │  Each flow entry maintains:                                                             │    │
│  │  • n_packets  - Number of packets matched                                               │    │
│  │  • n_bytes    - Number of bytes matched                                                 │    │
│  │  • duration   - How long the flow has been active                                       │    │
│  │  • idle_age   - Time since last packet matched                                          │    │
│  │  • hard_age   - Time since flow was installed                                           │    │
│  │                                                                                         │    │
│  │  Example flow with statistics:                                                          │    │
│  │  priority=1000,tcp,nw_dst=192.168.1.10,actions=output:2                                 │    │
│  │    └─ n_packets=1337, n_bytes=89642, duration=3600s, idle_age=45, hard_age=3600         │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Viewing Flow Tables

#### Basic Flow Dumps
```bash
# Dump all flows from a bridge
ovs-ofctl dump-flows br-int

# View flows for a specific table
ovs-ofctl dump-flows br-int table=0

# View flows with statistics
ovs-ofctl dump-flows br-int --stats

# Show flows in a more readable format
ovs-ofctl dump-flows br-int --names
```

#### Filtered Flow Views
```bash
# View flows for specific protocols
ovs-ofctl dump-flows br-int tcp
ovs-ofctl dump-flows br-int arp
ovs-ofctl dump-flows br-int icmp

# Filter by network addresses
ovs-ofctl dump-flows br-int nw_dst=192.168.1.10
ovs-ofctl dump-flows br-int nw_src=192.168.1.0/24

# Filter by ports
ovs-ofctl dump-flows br-int in_port=1
ovs-ofctl dump-flows br-int tcp,tp_dst=80
```

#### Table-Specific Views
```bash
# View specific OpenFlow tables
ovs-ofctl dump-flows br-int table=0    # Classification table
ovs-ofctl dump-flows br-int table=20   # Ingress port security
ovs-ofctl dump-flows br-int table=40   # Ingress table
ovs-ofctl dump-flows br-int table=60   # Egress table
```

### Adding Flow Rules

#### Basic Flow Addition
```bash
# Add simple forwarding rule
ovs-ofctl add-flow br-int priority=1000,in_port=1,actions=output:2

# Add rule with timeout
ovs-ofctl add-flow br-int \
  priority=2000,idle_timeout=300,tcp,nw_dst=192.168.1.10,actions=normal

# Add rule with hard timeout
ovs-ofctl add-flow br-int \
  priority=1500,hard_timeout=600,arp,actions=flood
```

#### Complex Flow Rules
```bash
# Multiple match criteria
ovs-ofctl add-flow br-int \
  "priority=3000,tcp,nw_src=192.168.1.0/24,nw_dst=192.168.2.0/24,tp_dst=80,actions=output:3"

# Multiple actions
ovs-ofctl add-flow br-int \
  "priority=2500,arp,actions=learn(table=1,priority=1000,NXM_OF_ETH_SRC[]),flood"

# VLAN manipulation
ovs-ofctl add-flow br-int \
  "priority=2000,in_port=1,actions=mod_vlan_vid:100,output:2"
```

#### Advanced Actions
```bash
# Load balancing with groups
ovs-ofctl add-group br-int \
  group_id=1,type=select,bucket=output:2,bucket=output:3

ovs-ofctl add-flow br-int \
  "priority=2000,tcp,tp_dst=80,actions=group:1"

# Connection tracking
ovs-ofctl add-flow br-int \
  "priority=1000,tcp,actions=ct(commit,table=1)"

# Packet marking
ovs-ofctl add-flow br-int \
  "priority=1500,tcp,actions=set_field:0x10->nw_tos,normal"
```

### Modifying and Deleting Flows

#### Flow Modification
```bash
# Modify actions for existing flows
ovs-ofctl mod-flows br-int priority=1000,actions=drop

# Modify specific flows
ovs-ofctl mod-flows br-int tcp,nw_dst=192.168.1.10,actions=output:5

# Strict modification (exact match)
ovs-ofctl mod-flows br-int --strict priority=1000,in_port=1,actions=normal
```

#### Flow Deletion
```bash
# Delete specific flows
ovs-ofctl del-flows br-int priority=1000,in_port=1

# Delete all flows matching criteria
ovs-ofctl del-flows br-int tcp,nw_dst=192.168.1.10

# Delete all flows from a table
ovs-ofctl del-flows br-int table=5

# Delete all flows
ovs-ofctl del-flows br-int
```

#### Batch Operations
```bash
# Replace all flows from file
ovs-ofctl replace-flows br-int flows.txt

# Add flows from file
ovs-ofctl add-flows br-int flows.txt

# Example flows.txt content:
cat <<'EOF' > flows.txt
priority=1000,in_port=1,actions=output:2
priority=2000,tcp,nw_dst=192.168.1.10,actions=normal
priority=500,actions=drop
EOF
```

## Switch Information and Statistics

### Bridge Information

#### Basic Switch Details
```bash
# Show bridge overview
ovs-ofctl show br-int

# Example output interpretation:
# OFPT_FEATURES_REPLY (xid=0x2): dpid:0000525400123456
#  n_tables:254, n_buffers:0
#  capabilities: FLOW_STATS TABLE_STATS PORT_STATS QUEUE_STATS ARP_MATCH_IP
#  actions: output enqueue set_vlan_vid set_vlan_pcp strip_vlan mod_dl_src mod_dl_dst mod_nw_src mod_nw_dst mod_nw_tos mod_tp_src mod_tp_dst
```

#### Detailed Bridge Information
```bash
# Get bridge description
ovs-ofctl dump-desc br-int

# Show supported OpenFlow features
ovs-ofctl dump-table-features br-int

# Check OpenFlow version
ovs-ofctl --version
```

### Port Information and Statistics

#### Port Status and Configuration
```bash
# Show all ports
ovs-ofctl dump-ports-desc br-int

# Show port statistics
ovs-ofctl dump-ports br-int

# Show statistics for specific port
ovs-ofctl dump-ports br-int 1

# Monitor port status changes
ovs-ofctl monitor br-int --detach
```

#### Port Statistics Analysis
```bash
# Analyze port utilization
#!/bin/bash
# port-stats-analysis.sh

bridge="br-int"
echo "=== Port Statistics Analysis for $bridge ==="

ovs-ofctl dump-ports $bridge | while read line; do
    if echo "$line" | grep -q "port"; then
        port=$(echo "$line" | grep -o "port [0-9]*" | cut -d' ' -f2)
        echo "Port $port:"
    elif echo "$line" | grep -q "rx pkts"; then
        rx_pkts=$(echo "$line" | grep -o "rx pkts=[0-9]*" | cut -d'=' -f2)
        echo "  RX packets: $rx_pkts"
    elif echo "$line" | grep -q "tx pkts"; then
        tx_pkts=$(echo "$line" | grep -o "tx pkts=[0-9]*" | cut -d'=' -f2)
        echo "  TX packets: $tx_pkts"
        echo ""
    fi
done
```

### Flow Statistics

#### Flow Table Statistics
```bash
# Show table-level statistics
ovs-ofctl dump-tables br-int

# Show aggregate flow statistics
ovs-ofctl dump-aggregate br-int

# Show per-flow packet/byte counts
ovs-ofctl dump-flows br-int | grep "n_packets" | head -10
```

#### Group and Queue Statistics
```bash
# Show group table statistics
ovs-ofctl dump-groups br-int
ovs-ofctl dump-group-stats br-int

# Show queue statistics
ovs-ofctl queue-stats br-int
ovs-ofctl queue-get-config br-int
```

## Debugging and Monitoring

### Debugging Workflow Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 OVS DEBUGGING WORKFLOW                                          │
│                                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                 PROBLEM IDENTIFICATION                                  │    │
│  │                                                                                         │    │
│  │  1. Issue Report: "VM1 cannot reach VM2"                                                │    │
│  │     ├─ Symptom: Network connectivity failure                                            │    │
│  │     ├─ Scope: Inter-VM communication                                                    │    │
│  │     └─ Environment: OVN/OVS SDN setup                                                   │    │
│  │                                                                                         │    │
│  │  2. Initial Information Gathering:                                                      │    │
│  │     ├─ VM1 IP: 192.168.1.10, MAC: AA:BB:CC:DD:EE:FF                                     │    │
│  │     ├─ VM2 IP: 192.168.1.20, MAC: 11:22:33:44:55:66                                     │    │
│  │     ├─ Logical Network: tenant-network                                                  │    │
│  │     └─ Chassis: compute-node-1, compute-node-2                                          │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                            │                                                    │
│                                            ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                 LAYER 1: PHYSICAL VERIFICATION                          │    │
│  │                                                                                         │    │
│  │  Commands:                                    Expected Results:                         │    │
│  │  ┌─────────────────────────────────────────┬─────────────────────────────────────────┐  │    │
│  │  │ ovs-vsctl show                          │ Bridge br-int exists                    │  │    │
│  │  │ ovs-ofctl show br-int                   │ All ports UP                            │  │    │
│  │  │ ovs-ofctl dump-ports br-int             │ No excessive drops/errors               │  │    │
│  │  │ ip link show                            │ Interfaces up                           │  │    │
│  │  └─────────────────────────────────────────┴─────────────────────────────────────────┘  │    │
│  │                                                                                         │    │
│  │  Status: ✅ PASS → Continue to Layer 2   |   ❌ FAIL → Fix physical issues             │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                            │                                                    │
│                                            ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                 LAYER 2: FLOW TABLE ANALYSIS                            │    │
│  │                                                                                         │    │
│  │  Commands:                                    Analysis:                                 │    │
│  │  ┌─────────────────────────────────────────┬─────────────────────────────────────────┐  │    │
│  │  │ ovs-ofctl dump-flows br-int             │ Check flow table structure              │  │    │
│  │  │ ovs-ofctl dump-flows br-int \           │ Find VM1 ingress/egress rules           │  │    │
│  │  │   | grep 192.168.1.10                   │                                         │  │    │
│  │  │ ovs-ofctl dump-flows br-int \           │ Find VM2 ingress/egress rules           │  │    │
│  │  │   | grep 192.168.1.20                   │                                         │  │    │
│  │  │ ovs-ofctl dump-flows br-int \           │ Check for drop rules                    │  │    │
│  │  │   | grep "actions=drop"                 │                                         │  │    │
│  │  └─────────────────────────────────────────┴─────────────────────────────────────────┘  │    │
│  │                                                                                         │    │
│  │  Status: ✅ PASS → Continue to Layer 3   |   ❌ FAIL → Fix flow rules                  │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                            │                                                    │
│                                            ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                 LAYER 3: PACKET TRACING                                 │    │
│  │                                                                                         │    │
│  │  Trace Command:                                                                         │    │
│  │  ovs-appctl ofproto/trace br-int \                                                      │    │
│  │    'in_port(1),eth(src=AA:BB:CC:DD:EE:FF,dst=11:22:33:44:55:66), \                      │    │
│  │     eth_type(0x0800),ipv4(src=192.168.1.10,dst=192.168.1.20,proto=1), \                 │    │
│  │     icmp(type=8,code=0)'                                                                │    │
│  │                                                                                         │    │
│  │  Analysis Points:                                                                       │    │
│  │  ┌──────────────────────────────────────────────────────────────────────────────────┐   │    │
│  │  │ • Table 0: Packet classification - VLAN tagging, tunnel decap                    │   │    │
│  │  │ • Table 1: Port security - MAC/IP validation                                     │   │    │
│  │  │ • Table 2: ACL processing - Security group rules                                 │   │    │
│  │  │ • Table 3: L2 learning - MAC address learning                                    │   │    │
│  │  │ • Table 4: Forwarding - Final packet disposition                                 │   │    │
│  │  │                                                                                  │   │    │
│  │  │ Final Action: output:2 (expected) vs drop/controller (problem)                   │   │    │
│  │  └──────────────────────────────────────────────────────────────────────────────────┘   │    │
│  │                                                                                         │    │
│  │  Status: ✅ PASS → Continue to Layer 4   |   ❌ FAIL → Analyze failed table            │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                            │                                                    │
│                                            ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                 LAYER 4: OVN CORRELATION                                │    │
│  │                                                                                         │    │
│  │  OVN Verification Commands:                                                             │    │
│  │  ┌──────────────────────────────────────────────────────────────────────────────────┐   │    │
│  │  │ ovn-nbctl show                      # Logical network topology                   │   │    │
│  │  │ ovn-sbctl show                      # Physical binding status                    │   │    │
│  │  │ ovn-sbctl lflow-list | grep VM1     # Logical flows for VM1                      │   │    │
│  │  │ ovn-sbctl lflow-list | grep VM2     # Logical flows for VM2                      │   │    │
│  │  │ ovn-sbctl get port_binding VM1 \    # Get tunnel key for VM1                     │   │    │
│  │  │   tunnel_key                        #                                            │   │    │
│  │  └──────────────────────────────────────────────────────────────────────────────────┘   │    │
│  │                                                                                         │    │
│  │  Correlation Check:                                                                     │    │
│  │  ┌──────────────────────────────────────────────────────────────────────────────────┐   │    │
│  │  │ OVN Logical Flows ──────────────► OpenFlow Rules                                 │   │    │
│  │  │                                                                                  │   │    │
│  │  │ ls_in_acl: allow tcp dst 80 ────► table=2,tcp,tp_dst=80,actions=resubmit(,3)     │   │    │
│  │  │ ls_in_l2_lkup: output port ─────► table=3,dl_dst=11:22:33:44:55:66,output:2      │   │    │
│  │  │                                                                                  │   │    │
│  │  │ Mismatch = Translation Problem                                                   │   │    │
│  │  └──────────────────────────────────────────────────────────────────────────────────┘   │    │
│  │                                                                                         │    │
│  │  Status: ✅ PASS → Continue to Layer 5   |   ❌ FAIL → Check ovn-controller            │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                            │                                                    │
│                                            ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                 LAYER 5: STATISTICAL ANALYSIS                           │    │
│  │                                                                                         │    │
│  │  Performance Metrics:                                                                   │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │ Flow Statistics:                                                                │    │    │
│  │  │ • n_packets=0 → Flow never matched (rule problem)                               │    │    │
│  │  │ • n_packets>0 → Flow matched but packet dropped elsewhere                       │    │    │
│  │  │ • idle_age=0 → Recent activity (good)                                           │    │    │
│  │  │ • idle_age>300 → No recent activity (stale flow)                                │    │    │
│  │  │                                                                                 │    │    │
│  │  │ Port Statistics:                                                                │    │    │
│  │  │ • rx_dropped>0 → Input port issues                                              │    │    │
│  │  │ • tx_dropped>0 → Output port issues                                             │    │    │
│  │  │ • rx_errors>0 → Physical layer problems                                         │    │    │
│  │  │                                                                                 │    │    │
│  │  │ Table Statistics:                                                               │    │    │
│  │  │ • table lookup vs matched → Miss rate analysis                                  │    │    │
│  │  │ • High miss rate → Flow table optimization needed                               │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  │                                                                                         │    │
│  │  Status: ✅ PASS → Problem Resolved   |   ❌ FAIL → Deep dive analysis                 │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                            │                                                    │
│                                            ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                 RESOLUTION & DOCUMENTATION                              │    │
│  │                                                                                         │    │
│  │  Actions Taken:                                                                         │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │ Problem Found: Missing ACL rule for ICMP traffic                                │    │    │
│  │  │                                                                                 │    │    │
│  │  │ Solution Applied:                                                               │    │    │
│  │  │ ovs-ofctl add-flow br-int \                                                     │    │    │
│  │  │   "priority=1000,icmp,nw_src=192.168.1.10,nw_dst=192.168.1.20,actions=normal"   │    │    │
│  │  │                                                                                 │    │    │
│  │  │ Verification:                                                                   │    │    │
│  │  │ ovs-appctl ofproto/trace br-int [test_packet] → output:2 ✅                     │   │    │
│  │  │                                                                                 │    │    │
│  │  │ Documentation: Update network ACL documentation with ICMP requirements          │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Packet Tracing Workflow

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                               PACKET TRACING WITH ovs-appctl                                    │
│                                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                INPUT PACKET                                             │    │
│  │                                                                                         │    │
│  │  ovs-appctl ofproto/trace br-int \                                                      │    │
│  │    'in_port(1),eth(src=AA:BB:CC:DD:EE:FF,dst=11:22:33:44:55:66), \                      │    │
│  │     eth_type(0x0800),ipv4(src=192.168.1.10,dst=192.168.1.20,proto=6), \                 │    │
│  │     tcp(src=12345,dst=80)'                                                              │    │
│  │                                                                                         │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │                           PACKET STRUCTURE                                      │    │    │
│  │  │                                                                                 │    │    │
│  │  │  Ethernet Header:                                                               │    │    │
│  │  │  ┌──────────────┬──────────────┬──────────────┐                                 │    │    │
│  │  │  │ Dst MAC      │ Src MAC      │ EtherType    │                                 │    │    │
│  │  │  │ 11:22:33:44  │ AA:BB:CC:DD  │ 0x0800 (IP) │                                  │    │    │
│  │  │  │ :55:66       │ :EE:FF       │              │                                 │    │    │
│  │  │  └──────────────┴──────────────┴──────────────┘                                 │    │    │
│  │  │                                                                                 │    │    │
│  │  │  IP Header:                                                                     │    │    │
│  │  │  ┌──────────────┬──────────────┬──────────────┬──────────────┐                  │    │    │
│  │  │  │ Src IP       │ Dst IP       │ Protocol     │ Other Fields │                  │    │    │
│  │  │  │ 192.168.1.10 │ 192.168.1.20 │ 6 (TCP)      │ ToS, TTL...  │                  │    │    │
│  │  │  └──────────────┴──────────────┴──────────────┴──────────────┘                  │    │    │
│  │  │                                                                                 │    │    │
│  │  │  TCP Header:                                                                    │    │    │
│  │  │  ┌──────────────┬──────────────┬──────────────┬──────────────┐                  │    │    │
│  │  │  │ Src Port     │ Dst Port     │ Flags        │ Other Fields │                  │    │    │
│  │  │  │ 12345        │ 80           │ SYN          │ Seq, Ack...  │                  │    │    │
│  │  │  └──────────────┴──────────────┴──────────────┴──────────────┘                  │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                                │                                                │
│                                                ▼                                                │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                              FLOW TABLE PROCESSING                                      │    │
│  │                                                                                         │    │
│  │  Table 0: Classification                                                                │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │ Flow: priority=32768,in_port=1,dl_vlan=0xffff ──────────────────── MATCH        │    │    │
│  │  │ Actions: mod_vlan_vid:100,resubmit(,1)                                          │    │    │
│  │  │                                                                                 │    │    │
│  │  │ Result: Packet gets VLAN tag 100, continue to table 1                           │    │    │
│  │  │ Packet state: in_port=1, dl_vlan=100, src=AA:BB:CC:DD:EE:FF                     │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  │                                          │                                              │    │
│  │                                          ▼                                              │    │
│  │  Table 1: Port Security                                                                 │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │ Flow: priority=50,in_port=1,dl_src=AA:BB:CC:DD:EE:FF ──────────── MATCH         │    │    │
│  │  │ Actions: resubmit(,2)                                                           │    │    │
│  │  │                                                                                 │    │    │
│  │  │ Result: Source MAC validated, continue to table 2                               │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  │                                          │                                              │    │
│  │                                          ▼                                              │    │
│  │  Table 2: ACL Processing                                                                │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │ Flow: priority=1000,tcp,tp_dst=80 ──────────────────────────────── MATCH        │    │    │
│  │  │ Actions: resubmit(,3)                                                           │    │    │
│  │  │                                                                                 │    │    │
│  │  │ Result: TCP port 80 allowed, continue to table 3                                │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  │                                          │                                              │    │
│  │                                          ▼                                              │    │
│  │  Table 3: L2 Learning/Forwarding                                                        │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │ Flow: priority=50,dl_dst=11:22:33:44:55:66 ─────────────────────── MATCH        │    │    │
│  │  │ Actions: strip_vlan,output:2                                                    │    │    │
│  │  │                                                                                 │    │    │
│  │  │ Result: Remove VLAN tag, send to port 2                                         │    │    │
│  │  │ Final packet: Ethernet frame sent to physical port 2                            │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                                │                                                │
│                                                ▼                                                │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                TRACE OUTPUT                                             │    │
│  │                                                                                         │    │
│  │  Flow: table=0, priority=32768,in_port=1 actions=mod_vlan_vid:100,resubmit(,1)          │    │
│  │        -> Packet now has VLAN 100                                                       │    │
│  │                                                                                         │    │
│  │  Flow: table=1, priority=50,in_port=1,dl_src=AA:BB:CC:DD:EE:FF actions=resubmit(,2)     │    │
│  │        -> Source MAC check passed                                                       │    │
│  │                                                                                         │    │
│  │  Flow: table=2, priority=1000,tcp,tp_dst=80 actions=resubmit(,3)                        │    │
│  │        -> TCP port 80 allowed                                                           │    │
│  │                                                                                         │    │
│  │  Flow: table=3, priority=50,dl_dst=11:22:33:44:55:66 actions=strip_vlan,output:2        │    │
│  │        -> VLAN stripped, output to port 2                                               │    │
│  │                                                                                         │    │
│  │  Final flow: in_port=1,dl_vlan=0xffff,dl_src=AA:BB:CC:DD:EE:FF,dl_dst=11:22:33:44:55:66,dl_type=0x0800 │
│  │  Datapath actions: strip_vlan,2                                                         │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Flow Statistics and Monitoring

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              FLOW STATISTICS MONITORING                                         │
│                                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                FLOW ENTRY STATISTICS                                    │    │
│  │                                                                                         │    │
│  │  ovs-ofctl dump-flows br-int --stats                                                    │    │
│  │                                                                                         │    │
│  │  Sample Output:                                                                         │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │ cookie=0x0, duration=3661.349s, table=0, n_packets=1057, n_bytes=98234,         │    │    │
│  │  │ idle_age=12, hard_age=3661, priority=32768,in_port=1,dl_vlan=0xffff             │    │    │
│  │  │ actions=mod_vlan_vid:100,resubmit(,1)                                           │    │    │
│  │  │                                                                                 │    │    │
│  │  │ cookie=0x0, duration=3600.125s, table=1, n_packets=1057, n_bytes=98234,         │    │    │
│  │  │ idle_age=12, hard_age=3600, priority=50,in_port=1,dl_src=aa:bb:cc:dd:ee:ff      │    │    │
│  │  │ actions=resubmit(,2)                                                            │    │    │
│  │  │                                                                                 │    │    │
│  │  │ cookie=0x0, duration=1800.456s, table=2, n_packets=856, n_bytes=79432,          │    │    │
│  │  │ idle_age=12, hard_age=1800, priority=1000,tcp,tp_dst=80                         │    │    │
│  │  │ actions=resubmit(,3)                                                            │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  │                                                                                         │    │
│  │  Statistics Breakdown:                                                                  │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │ • duration     - How long flow has been installed (seconds)                     │    │    │
│  │  │ • n_packets    - Total packets matched by this flow                             │    │    │
│  │  │ • n_bytes      - Total bytes matched by this flow                               │    │    │
│  │  │ • idle_age     - Seconds since last packet matched                              │    │    │
│  │  │ • hard_age     - Seconds since flow installation                                │    │    │
│  │  │ • priority     - Flow priority (higher = more specific)                         │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                               PORT STATISTICS                                           │    │
│  │                                                                                         │    │
│  │  ovs-ofctl dump-ports br-int                                                            │    │
│  │                                                                                         │    │
│  │  Sample Output:                                                                         │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │ OFPST_PORT reply (xid=0x4): 4 ports                                             │    │    │
│  │  │   port  1: rx pkts=1057, bytes=98234, drop=0, errs=0, frame=0, over=0, crc=0    │    │    │
│  │  │            tx pkts=2891, bytes=267842, drop=0, errs=0, coll=0                   │    │    │
│  │  │   port  2: rx pkts=2891, bytes=267842, drop=0, errs=0, frame=0, over=0, crc=0   │    │    │
│  │  │            tx pkts=1057, bytes=98234, drop=0, errs=0, coll=0                    │    │    │
│  │  │   port LOCAL: rx pkts=0, bytes=0, drop=0, errs=0, frame=0, over=0, crc=0        │    │    │
│  │  │               tx pkts=0, bytes=0, drop=0, errs=0, coll=0                        │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  │                                                                                         │    │
│  │  Port Metrics:                                                                          │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │ • rx pkts/bytes  - Received packets/bytes                                       │    │    │
│  │  │ • tx pkts/bytes  - Transmitted packets/bytes                                    │    │    │
│  │  │ • drop           - Dropped packets                                              │    │    │
│  │  │ • errs           - Error packets                                                │    │    │
│  │  │ • frame/over/crc - Layer 1 errors                                               │    │    │
│  │  │ • coll           - Collision errors                                             │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                              TABLE STATISTICS                                           │    │
│  │                                                                                         │    │
│  │  ovs-ofctl dump-tables br-int                                                           │    │
│  │                                                                                         │    │
│  │  Sample Output:                                                                         │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │ OFPST_TABLE reply (xid=0x2): 254 tables                                         │    │    │
│  │  │   table 0: active=3, lookup=1057, matched=1057                                  │    │    │
│  │  │   table 1: active=2, lookup=1057, matched=1057                                  │    │    │
│  │  │   table 2: active=5, lookup=1057, matched=856                                   │    │    │
│  │  │   table 3: active=10, lookup=856, matched=856                                   │    │    │
│  │  │   table 4: active=0, lookup=0, matched=0                                        │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  │                                                                                         │    │
│  │  Table Metrics:                                                                         │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │ • active   - Number of active flows in table                                    │    │    │
│  │  │ • lookup   - Number of packets processed by table                               │    │    │
│  │  │ • matched  - Number of packets matched by flows in table                        │    │    │
│  │  │                                                                                 │    │    │
│  │  │ Miss Rate = (lookup - matched) / lookup                                         │    │    │
│  │  │ Table 2 miss rate = (1057 - 856) / 1057 = 19%                                   │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Packet Tracing

#### Basic Packet Tracing
```bash
# Trace packet through flow tables
ovs-appctl ofproto/trace br-int \
  in_port=1,dl_src=52:54:00:12:34:56,dl_dst=52:54:00:12:34:57

# Trace with IP details
ovs-appctl ofproto/trace br-int \
  'in_port(1),eth(src=52:54:00:12:34:56,dst=52:54:00:12:34:57),eth_type(0x0800),ipv4(src=192.168.1.10,dst=192.168.1.20,proto=6),tcp(src=12345,dst=80)'
```

#### Advanced Packet Tracing
```bash
# Trace with tunnel metadata
ovs-appctl ofproto/trace br-int \
  'tunnel(tun_id=0x5,src=10.0.0.1,dst=10.0.0.2),in_port(1),eth(src=52:54:00:12:34:56,dst=52:54:00:12:34:57)'

# Trace with VLAN tags
ovs-appctl ofproto/trace br-int \
  'in_port(1),eth(src=52:54:00:12:34:56,dst=52:54:00:12:34:57),eth_type(0x8100),vlan(vid=100,pcp=0),encap(eth_type(0x0800))'

# Generate packet and trace
ovs-appctl ofproto/trace br-int \
  'in_port(1),eth_type(0x0800),ipv4(src=192.168.1.10,dst=192.168.1.20)' \
  -generate
```

### Real-Time Monitoring and Alerting

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                           OVS MONITORING AND ALERTING ARCHITECTURE                              │
│                                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                 DATA COLLECTION LAYER                                   │    │
│  │                                                                                         │    │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │    │
│  │  │  Flow Metrics   │  │  Port Metrics   │  │ Table Metrics   │  │ System Metrics  │     │    │
│  │  │                 │  │                 │  │                 │  │                 │     │    │
│  │  │• n_packets      │  │• rx_packets     │  │• active_flows   │  │• CPU usage      │     │    │
│  │  │• n_bytes        │  │• tx_packets     │  │• lookup_count   │  │• Memory usage   │     │    │
│  │  │• duration       │  │• rx_dropped     │  │• matched_count  │  │• Disk I/O       │     │    │
│  │  │• idle_age       │  │• tx_dropped     │  │• miss_count     │  │• Network I/O    │     │    │
│  │  │                 │  │• rx_errors      │  │                 │  │                 │     │    │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────────┘     │    │
│  │           │                     │                     │                     │           │    │
│  │           │                     │                     │                     │           │    │
│  │           ▼                     ▼                     ▼                     ▼           │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │                         COLLECTION COMMANDS                                     │    │    │
│  │  │                                                                                 │    │    │
│  │  │ ovs-ofctl dump-flows br-int --stats                                             │    │    │
│  │  │ ovs-ofctl dump-ports br-int                                                     │    │    │
│  │  │ ovs-ofctl dump-tables br-int                                                    │    │    │
│  │  │ ovs-vsctl show                                                                  │    │    │
│  │  │ ovs-appctl coverage/show                                                        │    │    │
│  │  │ ovs-appctl upcall/show                                                          │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                                │                                                │
│                                                ▼                                                │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                               PROCESSING & ANALYSIS LAYER                               │    │
│  │                                                                                         │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │                           METRIC PROCESSING                                     │    │    │
│  │  │                                                                                 │    │    │
│  │  │  Raw Metrics ────────────► Calculated Metrics ────────────► Thresholds          │    │    │
│  │  │                                                                                 │    │    │
│  │  │  • Flow count             • Flows/second rate          • > 10,000 flows         │    │    │
│  │  │  • Packet count           • Packets/second rate        • > 100,000 pps          │    │    │
│  │  │  • Byte count             • Throughput (Mbps)          • > 1 Gbps               │    │    │
│  │  │  • Drop count             • Drop rate (%)              • > 1% drop rate         │    │    │
│  │  │  • Error count            • Error rate (%)             • > 0.1% error rate      │    │    │
│  │  │  • Table lookups          • Miss rate (%)              • > 10% miss rate        │    │    │
│  │  │                                                                                 │    │    │
│  │  │  ┌─────────────────────────────────────────────────────────────────────────┐    │    │    │
│  │  │  │                    ANALYSIS ALGORITHMS                                  │    │    │    │
│  │  │  │                                                                         │    │    │    │
│  │  │  │ 1. Trend Analysis:                                                      │    │    │    │
│  │  │  │    • Moving averages (5min, 15min, 1hr)                                 │    │    │    │
│  │  │  │    • Rate of change calculations                                        │    │    │    │
│  │  │  │    • Seasonal pattern detection                                         │    │    │    │
│  │  │  │                                                                         │    │    │    │
│  │  │  │ 2. Anomaly Detection:                                                   │    │    │    │
│  │  │  │    • Statistical outlier detection                                      │    │    │    │
│  │  │  │    • Machine learning-based anomaly detection                           │    │    │    │
│  │  │  │    • Threshold-based alerting                                           │    │    │    │
│  │  │  │                                                                         │    │    │    │
│  │  │  │ 3. Correlation Analysis:                                                │    │    │    │
│  │  │  │    • Cross-metric correlation                                           │    │    │    │
│  │  │  │    • System-level impact analysis                                       │    │    │    │
│  │  │  │    • Root cause analysis                                                │    │    │    │
│  │  │  └─────────────────────────────────────────────────────────────────────────┘    │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                                │                                                │
│                                                ▼                                                │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                ALERTING & NOTIFICATION LAYER                            │    │
│  │                                                                                         │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │                           ALERT CLASSIFICATION                                  │    │    │
│  │  │                                                                                 │    │    │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │    │    │
│  │  │  │  CRITICAL   │  │   WARNING   │  │    INFO     │  │   DEBUG     │             │    │    │
│  │  │  │             │  │             │  │             │  │             │             │    │    │
│  │  │  │• System     │  │• High CPU   │  │• New flow   │  │• Flow age   │             │    │    │
│  │  │  │  failure    │  │• High drop  │  │  patterns   │  │  statistics │             │    │    │
│  │  │  │• Network    │  │  rate       │  │• Topology   │  │• Performance│             │    │    │
│  │  │  │  partition  │  │• Table      │  │  changes    │  │  metrics    │             │    │    │
│  │  │  │• Security   │  │  overflow   │  │• Config     │  │• Trace      │             │    │    │
│  │  │  │  breach     │  │• Port down  │  │  updates    │  │  results    │             │    │    │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘             │    │    │
│  │  │           │               │               │               │                     │    │    │
│  │  │           │               │               │               │                     │    │    │
│  │  └───────────┼───────────────┼───────────────┼───────────────┼─────────────────────┘    │    │
│  │              │               │               │               │                          │    │
│  │              ▼               ▼               ▼               ▼                          │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │                        NOTIFICATION CHANNELS                                    │    │    │
│  │  │                                                                                 │    │    │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │    │    │
│  │  │  │   EMAIL     │  │    SLACK    │  │    PAGER    │  │  DASHBOARD  │             │    │    │
│  │  │  │             │  │             │  │             │  │             │             │    │    │
│  │  │  │• Detailed   │  │• Quick      │  │• Immediate  │  │• Visual     │             │    │    │
│  │  │  │  reports    │  │  alerts     │  │  critical   │  │  metrics    │             │    │    │
│  │  │  │• Graphs     │  │• Team       │  │  alerts     │  │• Historical │             │    │    │
│  │  │  │• Logs       │  │  channels   │  │• Escalation │  │  trends     │             │    │    │
│  │  │  │• Analysis   │  │• Bot        │  │• On-call    │  │• Real-time  │             │    │    │
│  │  │  │              │  │  commands   │  │  rotation   │  │  status     │            │    │    │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘             │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                                │                                                │
│                                                ▼                                                │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                              AUTOMATED RESPONSE LAYER                                   │    │
│  │                                                                                         │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │                          RESPONSE ACTIONS                                       │    │    │
│  │  │                                                                                 │    │    │
│  │  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                  │    │    │
│  │  │  │  SELF-HEALING   │  │   MITIGATION    │  │  INVESTIGATION  │                  │    │    │
│  │  │  │                 │  │                 │  │                 │                  │    │    │
│  │  │  │• Restart        │  │• Rate limiting  │  │• Collect logs   │                  │    │    │
│  │  │  │  services       │  │• Traffic        │  │• Capture        │                  │    │    │
│  │  │  │• Clear flows    │  │  shaping        │  │  packets        │                  │    │    │
│  │  │  │• Recreate       │  │• Failover       │  │• Generate       │                  │    │    │
│  │  │  │  interfaces     │  │• Isolation      │  │  reports        │                  │    │    │
│  │  │  │• Restart        │  │• Quarantine     │  │• Trigger        │                  │    │    │
│  │  │  │  controllers    │  │                 │  │  traces         │                  │    │    │
│  │  │  └─────────────────┘  └─────────────────┘  └─────────────────┘                  │    │    │
│  │  │                                                                                 │    │    │
│  │  │  ┌─────────────────────────────────────────────────────────────────────────┐    │    │    │
│  │  │  │                    AUTOMATION WORKFLOW                                  │    │    │    │
│  │  │  │                                                                         │    │    │    │
│  │  │  │ 1. Alert Received → 2. Analyze Severity → 3. Execute Response           │    │    │    │
│  │  │  │         │                    │                        │                 │    │    │    │
│  │  │  │         ▼                    ▼                        ▼                 │    │    │    │
│  │  │  │ Parse alert data    Check runbook rules    Run automation script        |    │    │    │
│  │  │  │ Extract context     Validate conditions    Monitor results              │    │    │    │
│  │  │  │ Identify resources  Check dependencies     Update status                │    │    │    │
│  │  │  │                                                                         │    │    │    │
│  │  │  │ 4. Verify Resolution → 5. Update Records → 6. Close Incident            │    │    │    │
│  │  │  │         │                       │                       │               │    │    │    │
│  │  │  │         ▼                       ▼                       ▼               │    │    │    │
│  │  │  │ Test connectivity      Log resolution steps    Notify stakeholders      │    │    │    │
│  │  │  │ Validate metrics       Update documentation    Generate reports         │    │    │    │
│  │  │  │ Confirm stability      Archive artifacts       Schedule review          │    │    │    │
│  │  │  └─────────────────────────────────────────────────────────────────────────┘    │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                                │                                                │
│                                                ▼                                                │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                              REPORTING & ANALYTICS LAYER                                │    │
│  │                                                                                         │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │                            REPORT TYPES                                         │    │    │
│  │  │                                                                                 │    │    │
│  │  │ 1. Real-time Dashboards:                                                        │    │    │
│  │  │    • Live flow statistics                                                       │    │    │
│  │  │    • Network topology status                                                    │    │    │
│  │  │    • Performance metrics                                                        │    │    │
│  │  │    • Alert status                                                               │    │    │
│  │  │                                                                                 │    │    │
│  │  │ 2. Historical Reports:                                                          │    │    │
│  │  │    • Weekly/monthly trends                                                      │    │    │
│  │  │    • Capacity planning data                                                     │    │    │
│  │  │    • Incident analysis                                                          │    │    │
│  │  │    • Performance baselines                                                      │    │    │
│  │  │                                                                                 │    │    │
│  │  │ 3. Predictive Analytics:                                                        │    │    │
│  │  │    • Capacity forecasting                                                       │    │    │
│  │  │    • Failure prediction                                                         │    │    │
│  │  │    • Optimization recommendations                                               │    │    │
│  │  │    • Maintenance scheduling                                                     │    │    │
│  │  │                                                                                 │    │    │
│  │  │ 4. Compliance Reports:                                                          │    │    │
│  │  │    • Security audit trails                                                      │    │    │
│  │  │    • Performance SLA tracking                                                   │    │    │
│  │  │    • Change management logs                                                     │    │    │
│  │  │    • Regulatory compliance                                                      │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Flow Optimization and Performance Tuning

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              FLOW OPTIMIZATION METHODOLOGY                                      │
│                                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                PHASE 1: BASELINE ANALYSIS                               │    │
│  │                                                                                         │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │                         CURRENT STATE ASSESSMENT                                │    │    │
│  │  │                                                                                 │    │    │
│  │  │ Data Collection:                  Analysis Metrics:                             │    │    │
│  │  │ ├─ Flow table sizes              ├─ Table utilization (%)                       │    │    │
│  │  │ ├─ Flow priorities               ├─ Priority distribution                       │    │    │
│  │  │ ├─ Match criteria complexity     ├─ Match field usage                           │    │    │
│  │  │ ├─ Action types                  ├─ Action complexity                           │    │    │
│  │  │ ├─ Flow lifetimes                ├─ Timeout effectiveness                       │    │    │
│  │  │ └─ Traffic patterns              └─ Load distribution                           │    │    │
│  │  │                                                                                 │    │    │
│  │  │ Commands:                                                                       │    │    │
│  │  │ ┌───────────────────────────────────────────────────────────────────────────┐   │    │    │
│  │  │ │ ovs-ofctl dump-flows br-int | wc -l                                       │   │    │    │
│  │  │ │ ovs-ofctl dump-tables br-int                                              │   │    │    │
│  │  │ │ ovs-ofctl dump-flows br-int | grep -o "priority=[0-9]*" | sort | uniq -c  │   │    │    │
│  │  │ │ ovs-ofctl dump-flows br-int | grep -o "idle_timeout=[0-9]*" | sort | uniq -c  │    │    │
│  │  │ │ ovs-ofctl dump-flows br-int | grep -E "n_packets=[1-9]" | head -20        │   │    │    │
│  │  │ └───────────────────────────────────────────────────────────────────────────┘   │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                                │                                                │
│                                                ▼                                                │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                PHASE 2: BOTTLENECK IDENTIFICATION                       │    │
│  │                                                                                         │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │                           PERFORMANCE BOTTLENECKS                               │    │    │
│  │  │                                                                                 │    │    │
│  │  │ 1. Flow Table Hotspots:                                                         │    │    │
│  │  │    ┌─────────────────────────────────────────────────────────────────────┐      │    │    │
│  │  │    │ High Lookup Tables:                                                 │      │    │    │
│  │  │    │ • Table 0: 1M lookups/sec (Classification bottleneck)               │      │    │    │
│  │  │    │ • Table 2: 800K lookups/sec (ACL processing bottleneck)             │      │    │    │
│  │  │    │                                                                     │      │    │    │
│  │  │    │ High Miss Rates:                                                    │      │    │    │
│  │  │    │ • Table 3: 15% miss rate (MAC learning inefficiency)                │      │    │    │
│  │  │    │ • Table 5: 25% miss rate (Forwarding table gaps)                    │      │    │    │
│  │  │    └─────────────────────────────────────────────────────────────────────┘      │    │    │
│  │  │                                                                                 │    │    │
│  │  │ 2. Flow Efficiency Issues:                                                      │    │    │
│  │  │    ┌─────────────────────────────────────────────────────────────────────┐      │    │    │
│  │  │    │ Inefficient Flows:                                                  │      │    │    │
│  │  │    │ • 50+ flows with n_packets=0 (Unused flows)                         │      │    │    │
│  │  │    │ • 200+ flows with priority=0 (Inefficient catch-all)                │      │    │    │
│  │  │    │ • 30+ flows with complex match criteria (Slow matching)             │      │    │    │
│  │  │    │                                                                     │      │    │    │
│  │  │    │ Timeout Issues:                                                     │      │    │    │
│  │  │    │ • 100+ flows with idle_age > 3600 (Stale flows)                     │      │    │    │
│  │  │    │ • 20+ flows with no timeout (Permanent flows)                       │      │    │    │
│  │  │    └─────────────────────────────────────────────────────────────────────┘      │    │    │
│  │  │                                                                                 │    │    │
│  │  │ 3. Hardware/Software Limitations:                                               │    │    │
│  │  │    ┌─────────────────────────────────────────────────────────────────────┐      │    │    │
│  │  │    │ Resource Constraints:                                               │      │    │    │
│  │  │    │ • TCAM utilization: 85% (Hardware flow table full)                  │      │    │    │
│  │  │    │ • CPU utilization: 90% (Software processing overload)               │      │    │    │
│  │  │    │ • Memory usage: 75% (Flow cache pressure)                           │      │    │    │
│  │  │    │                                                                     │      │    │    │
│  │  │    │ Upcall Pressure:                                                    │      │    │    │
│  │  │    │ • 1000+ upcalls/sec (Miss-handling overhead)                        │      │    │    │
│  │  │    │ • 500ms average upcall latency (Slow controller)                    │      │    │    │
│  │  │    └─────────────────────────────────────────────────────────────────────┘      │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                                │                                                │
│                                                ▼                                                │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                PHASE 3: OPTIMIZATION STRATEGIES                         │    │
│  │                                                                                         │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │                           OPTIMIZATION TECHNIQUES                               │    │    │
│  │  │                                                                                 │    │    │
│  │  │ 1. Flow Table Restructuring:                                                    │    │    │
│  │  │    ┌─────────────────────────────────────────────────────────────────────┐      │    │    │
│  │  │    │ Before: Single Table Approach              After: Multi-Table       │      │    │    │
│  │  │    │                                                                     │      │    │    │
│  │  │    │ Table 0: 10,000 flows (All rules)         Table 0: 100 flows        │      │    │    │
│  │  │    │ ├─ Classification                          ├─ Classification        │      │    │    │
│  │  │    │ ├─ Security                                Table 1: 1,000 flows     │      │    │    │
│  │  │    │ ├─ Forwarding                              ├─ Security rules        │      │    │    │
│  │  │    │ └─ Default                                 Table 2: 5,000 flows     │      │    │    │
│  │  │    │                                            ├─ Forwarding rules      │      │    │    │
│  │  │    │ Lookup: O(n) = 10,000 checks              Table 3: 100 flows        │      │    │    │
│  │  │    │ Miss rate: 20%                             └─ Default rules         │      │    │    │
│  │  │    │                                                                     │      │    │    │
│  │  │    │                                            Lookup: O(log n) = 100   │      │    │    │
│  │  │    │                                            Miss rate: 5%            │      │    │    │
│  │  │    └─────────────────────────────────────────────────────────────────────┘      │    │    │
│  │  │                                                                                 │    │    │
│  │  │ 2. Flow Consolidation:                                                          │    │    │
│  │  │    ┌─────────────────────────────────────────────────────────────────────┐      │    │    │
│  │  │    │ Before: Granular Rules                     After: Aggregated Rules  │      │    │    │
│  │  │    │                                                                     │      │    │    │
│  │  │    │ 100 flows:                                 5 flows:                 │      │    │    │
│  │  │    │ tcp,nw_dst=192.168.1.1,actions=output:1   tcp,nw_dst=192.168.1.0/24 │      │    │    │
│  │  │    │ tcp,nw_dst=192.168.1.2,actions=output:1   actions=output:1          │      │    │    │
│  │  │    │ tcp,nw_dst=192.168.1.3,actions=output:1                             │      │    │    │
│  │  │    │ ...                                        udp,nw_dst=192.168.2.0/24 │     │    │    │
│  │  │    │ tcp,nw_dst=192.168.1.100,actions=output:1 actions=output:2          │      │    │    │
│  │  │    │                                                                     │      │    │    │
│  │  │    │ Benefits: 95% reduction in flows, faster lookups                    │      │    │    │
│  │  │    └─────────────────────────────────────────────────────────────────────┘      │    │    │
│  │  │                                                                                 │    │    │
│  │  │ 3. Priority Optimization:                                                       │    │    │
│  │  │    ┌─────────────────────────────────────────────────────────────────────┐      │    │    │
│  │  │    │ Priority Strategy:                                                  │      │    │    │
│  │  │    │                                                                     │      │    │    │
│  │  │    │ 32768: Emergency/Security (Block attacks)                           │      │    │    │
│  │  │    │ 16384: High-priority traffic (Management, DNS)                      │      │    │    │
│  │  │    │  8192: Normal application traffic                                   │      │    │    │
│  │  │    │  4096: Bulk traffic (Backup, replication)                           │      │    │    │
│  │  │    │  2048: Best-effort traffic                                          │      │    │    │
│  │  │    │  1024: Default forwarding                                           │      │    │    │
│  │  │    │     0: Catch-all drop                                               │      │    │    │
│  │  │    │                                                                     │      │    │    │
│  │  │    │ Match Optimization:                                                 │      │    │    │
│  │  │    │ • Most specific matches first (high priority)                       │      │    │    │
│  │  │    │ • Common patterns early (frequent matching)                         │      │    │    │
│  │  │    │ • Expensive operations last (complex actions)                       │      │    │    │
│  │  │    └─────────────────────────────────────────────────────────────────────┘      │    │    │
│  │  │                                                                                 │    │    │
│  │  │ 4. Timeout Tuning:                                                              │    │    │
│  │  │    ┌─────────────────────────────────────────────────────────────────────┐      │    │    │
│  │  │    │ Flow Category          Idle Timeout    Hard Timeout                 │      │    │    │
│  │  │    │ ─────────────────────────────────────────────────────────────────   │      │    │    │
│  │  │    │ Connection tracking    300 seconds     -                            │      │    │    │
│  │  │    │ MAC learning          600 seconds     3600 seconds                  │      │    │    │
│  │  │    │ ARP entries           300 seconds     1800 seconds                  │      │    │    │
│  │  │    │ Security rules        -               -                             │      │    │    │
│  │  │    │ Load balancing        60 seconds      300 seconds                   │      │    │    │
│  │  │    │ Temporary redirects   30 seconds      120 seconds                   │      │    │    │
│  │  │    │                                                                     │      │    │    │
│  │  │    │ Benefits: Automatic cleanup, reduced table size                     │      │    │    │
│  │  │    └─────────────────────────────────────────────────────────────────────┘      │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                                │                                                │
│                                                ▼                                                │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                PHASE 4: IMPLEMENTATION & TESTING                        │    │
│  │                                                                                         │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │                           DEPLOYMENT STRATEGY                                   │    │    │
│  │  │                                                                                 │    │    │
│  │  │ 1. Staging Environment:                                                         │    │    │
│  │  │    • Replicate production flow patterns                                         │    │    │
│  │  │    • Apply optimizations                                                        │    │    │
│  │  │    • Run performance tests                                                      │    │    │
│  │  │    • Validate functionality                                                     │    │    │
│  │  │                                                                                 │    │    │
│  │  │ 2. Gradual Rollout:                                                             │    │    │
│  │  │    • Start with non-critical flows                                              │    │    │
│  │  │    • Monitor performance metrics                                                │    │    │
│  │  │    • Incremental table migration                                                │    │    │
│  │  │    • Rollback procedures ready                                                  │    │    │
│  │  │                                                                                 │    │    │
│  │  │ 3. Performance Validation:                                                      │    │    │
│  │  │    ┌─────────────────────────────────────────────────────────────────────┐      │    │    │
│  │  │    │ Metric              Before      After       Improvement             │      │    │    │
│  │  │    │ ─────────────────────────────────────────────────────────────────── │      │    │    │
│  │  │    │ Flow count          10,000      2,000       80% reduction           │      │    │    │
│  │  │    │ Lookup time         50ms        5ms         90% improvement         │      │    │    │
│  │  │    │ Miss rate           20%         5%          75% improvement         │      │    │    │
│  │  │    │ CPU utilization     90%         45%         50% improvement         │      │    │    │
│  │  │    │ Memory usage        75%         40%         47% improvement         │      │    │    │
│  │  │    │ Throughput          1 Gbps      2.5 Gbps    150% improvement        │      │    │    │
│  │  │    └─────────────────────────────────────────────────────────────────────┘      │    │    │
│  │  │                                                                                 │    │    │
│  │  │ 4. Monitoring & Maintenance:                                                    │    │    │
│  │  │    • Continuous performance monitoring                                          │    │    │
│  │  │    • Automated flow cleanup                                                     │    │    │
│  │  │    • Regular optimization reviews                                               │    │    │
│  │  │    • Performance baseline updates                                               │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Real-Time Monitoring

#### Flow Monitoring
```bash
# Monitor flow table changes
ovs-ofctl monitor br-int watch:

# Monitor with timestamps
ovs-ofctl monitor br-int watch: --timestamp

# Monitor specific flow changes
ovs-ofctl monitor br-int watch: | grep -E "ADD|DEL|MODIFY"
```

#### Continuous Monitoring Script
```bash
#!/bin/bash
# ovs-monitor.sh

bridge="br-int"
log_file="/var/log/ovs-monitor.log"

echo "Starting OVS monitoring for $bridge..."

# Monitor flow changes
ovs-ofctl monitor $bridge watch: --timestamp >> $log_file &
monitor_pid=$!

# Monitor port statistics
while true; do
    echo "$(date): Port Statistics" >> $log_file
    ovs-ofctl dump-ports $bridge >> $log_file
    sleep 60
done &
stats_pid=$!

# Cleanup function
cleanup() {
    kill $monitor_pid $stats_pid 2>/dev/null
    exit 0
}

trap cleanup SIGINT SIGTERM
wait
```

## OVN Integration

### OVN-Specific Flow Analysis

#### Tunnel Key Analysis
```bash
# Find flows for specific tunnel key
tunnel_key=5
ovs-ofctl dump-flows br-int | grep "tunnel_key=$tunnel_key"

# Analyze tunnel key distribution
ovs-ofctl dump-flows br-int | grep -o "tunnel_key=[0-9]*" | \
  sort | uniq -c | sort -nr | head -10
```

#### Logical Port Flow Verification
```bash
#!/bin/bash
# verify-logical-port-flows.sh

logical_port="vm1-port"
tunnel_key=$(ovn-sbctl get port_binding $logical_port tunnel_key)
chassis=$(ovn-sbctl get port_binding $logical_port chassis)

echo "=== Flow Verification for $logical_port ==="
echo "Tunnel Key: $tunnel_key"
echo "Chassis: $chassis"

# Check ingress flows
echo -e "\nIngress flows (packets TO this port):"
ovs-ofctl dump-flows br-int | grep "tunnel_key=$tunnel_key" | \
  grep -E "actions=.*output"

# Check egress flows  
echo -e "\nEgress flows (packets FROM this port):"
ovs-ofctl dump-flows br-int | grep -E "in_port.*tunnel_key=$tunnel_key"

# Check for flow statistics
echo -e "\nFlow statistics:"
ovs-ofctl dump-flows br-int | grep "tunnel_key=$tunnel_key" | \
  grep -o "n_packets=[0-9]*" | head -5
```

#### OVN Logical Flow Correlation
```bash
#!/bin/bash
# correlate-ovn-flows.sh

echo "=== OVN Logical Flow to OpenFlow Correlation ==="

# Count logical flows
logical_flows=$(ovn-sbctl lflow-list | wc -l)
echo "OVN Logical Flows: $logical_flows"

# Count OpenFlow rules
openflow_rules=$(ovs-ofctl dump-flows br-int | wc -l)
echo "OpenFlow Rules: $openflow_rules"

# Check correlation ratio
if [ $openflow_rules -lt $((logical_flows / 3)) ]; then
    echo "WARNING: Low correlation ratio - check ovn-controller"
elif [ $openflow_rules -gt $((logical_flows * 3)) ]; then
    echo "INFO: High OpenFlow rule count - normal for complex policies"
else
    echo "OK: Normal correlation ratio"
fi

# Sample logical flow translation
echo -e "\nSample logical flow translation:"
ovn-sbctl lflow-list | head -3
echo -e "\nCorresponding OpenFlow rules:"
ovs-ofctl dump-flows br-int table=0 | head -3
```

### Debugging VM Connectivity

#### VM-to-VM Communication Debug
```bash
#!/bin/bash
# debug-vm-connectivity.sh

src_vm="vm1-port"
dst_vm="vm2-port"

echo "=== Debugging connectivity: $src_vm -> $dst_vm ==="

# Get tunnel keys
src_key=$(ovn-sbctl get port_binding $src_vm tunnel_key)
dst_key=$(ovn-sbctl get port_binding $dst_vm tunnel_key)

echo "Source tunnel key: $src_key"
echo "Destination tunnel key: $dst_key"

# Check source egress flows
echo -e "\nSource egress flows:"
ovs-ofctl dump-flows br-int | grep -E "tunnel_key=$src_key.*set_tunnel.*$dst_key"

# Check destination ingress flows
echo -e "\nDestination ingress flows:"
ovs-ofctl dump-flows br-int | grep "tunnel_key=$dst_key"

# Check tunnel interface
echo -e "\nTunnel interface status:"
ovs-vsctl show | grep -A5 -B5 "type: geneve"
```

## Common Commands Reference

### Essential Commands
```bash
# Flow management
ovs-ofctl add-flow <bridge> <flow>     # Add flow
ovs-ofctl mod-flows <bridge> <flow>    # Modify flows  
ovs-ofctl del-flows <bridge> <flow>    # Delete flows
ovs-ofctl dump-flows <bridge>          # Show flows

# Information gathering
ovs-ofctl show <bridge>                # Show bridge info
ovs-ofctl dump-ports <bridge>          # Show port stats
ovs-ofctl dump-tables <bridge>         # Show table stats
ovs-ofctl dump-groups <bridge>         # Show group entries

# Monitoring
ovs-ofctl monitor <bridge> watch:      # Monitor flow changes
ovs-appctl ofproto/trace <bridge> <packet>  # Trace packet
```

### Flow Match Criteria
```bash
# Layer 2 matches
in_port=<port>                         # Input port
dl_src=<mac>                          # Source MAC
dl_dst=<mac>                          # Destination MAC
dl_vlan=<vlan>                        # VLAN ID

# Layer 3 matches  
nw_src=<ip/mask>                      # Source IP
nw_dst=<ip/mask>                      # Destination IP
nw_proto=<proto>                      # IP protocol

# Layer 4 matches
tp_src=<port>                         # Source port
tp_dst=<port>                         # Destination port

# Protocol shortcuts
tcp, udp, icmp, arp                   # Protocol types
```

### Common Actions
```bash
# Output actions
actions=output:<port>                  # Send to port
actions=normal                         # Normal L2/L3 processing
actions=flood                         # Flood to all ports
actions=drop                          # Drop packet

# Modification actions
actions=mod_dl_src:<mac>              # Modify source MAC
actions=mod_nw_dst:<ip>               # Modify destination IP
actions=mod_vlan_vid:<vlan>           # Set VLAN ID
actions=strip_vlan                    # Remove VLAN tag

# Advanced actions
actions=learn(...)                    # Dynamic flow learning
actions=group:<id>                    # Send to group
actions=controller                    # Send to controller
```

## Practical Examples

### Network Troubleshooting

#### Connectivity Testing
```bash
#!/bin/bash
# test-connectivity.sh

src_ip="192.168.1.10"
dst_ip="192.168.1.20"
bridge="br-int"

echo "=== Testing connectivity: $src_ip -> $dst_ip ==="

# Find relevant flows
echo "Flows matching source IP:"
ovs-ofctl dump-flows $bridge nw_src=$src_ip

echo -e "\nFlows matching destination IP:"
ovs-ofctl dump-flows $bridge nw_dst=$dst_ip

# Check for drop rules
echo -e "\nDrop rules:"
ovs-ofctl dump-flows $bridge | grep "actions=drop"

# Simulate packet trace
echo -e "\nPacket trace simulation:"
ovs-appctl ofproto/trace $bridge \
  "in_port(1),eth_type(0x0800),ipv4(src=$src_ip,dst=$dst_ip,proto=1),icmp(type=8,code=0)"
```

#### Performance Analysis
```bash
#!/bin/bash
# performance-analysis.sh

bridge="br-int"

echo "=== Performance Analysis for $bridge ==="

# Flow table utilization
total_flows=$(ovs-ofctl dump-flows $bridge | wc -l)
echo "Total flows: $total_flows"

# Table distribution
echo -e "\nFlows per table:"
ovs-ofctl dump-flows $bridge | \
  grep -o "table=[0-9]*" | sort | uniq -c | sort -nr

# High-traffic flows
echo -e "\nTop 10 highest traffic flows:"
ovs-ofctl dump-flows $bridge | \
  grep -o "n_packets=[0-9]*" | \
  sort -t= -k2 -nr | head -10

# Port utilization
echo -e "\nPort packet counts:"
ovs-ofctl dump-ports $bridge | \
  grep -E "port|rx pkts|tx pkts" | \
  paste - - - | head -10
```

### Security Analysis

#### Security Policy Verification
```bash
#!/bin/bash
# security-policy-check.sh

bridge="br-int"

echo "=== Security Policy Analysis ==="

# Find security-related flows
echo "Security group flows (high priority):"
ovs-ofctl dump-flows $bridge | grep "priority=2[0-9][0-9][0-9]" | head -10

# Check for explicit allow rules
echo -e "\nExplicit allow rules:"
ovs-ofctl dump-flows $bridge | grep -E "actions=.*output|normal" | \
  grep -v "actions=drop" | head -5

# Check for deny/drop rules
echo -e "\nDeny/drop rules:"
ovs-ofctl dump-flows $bridge | grep "actions=drop" | head -5

# Default policy check
echo -e "\nDefault policy (lowest priority flows):"
ovs-ofctl dump-flows $bridge | grep "priority=0" | head -3
```

### Load Balancing Verification

#### Group Table Analysis
```bash
#!/bin/bash
# load-balancing-check.sh

bridge="br-int"

echo "=== Load Balancing Analysis ==="

# Show group configurations
echo "Group table entries:"
ovs-ofctl dump-groups $bridge

# Show group statistics
echo -e "\nGroup statistics:"
ovs-ofctl dump-group-stats $bridge

# Find flows using groups
echo -e "\nFlows using load balancing groups:"
ovs-ofctl dump-flows $bridge | grep "actions=group" | head -5

# Analyze group utilization
ovs-ofctl dump-group-stats $bridge | while read line; do
    if echo "$line" | grep -q "group_id"; then
        echo "$line"
    elif echo "$line" | grep -q "packet_count"; then
        echo "  $line"
    fi
done
```

## Advanced Usage

### Custom Flow Analysis

#### Flow Aging and Timeouts
```bash
# Monitor flow aging
#!/bin/bash
# flow-aging-monitor.sh

bridge="br-int"

while true; do
    echo "$(date): Flow aging analysis"
    
    # Count flows with different timeouts
    echo "Flows with idle timeout:"
    ovs-ofctl dump-flows $bridge | grep "idle_timeout" | wc -l
    
    echo "Flows with hard timeout:"
    ovs-ofctl dump-flows $bridge | grep "hard_timeout" | wc -l
    
    echo "Permanent flows:"
    ovs-ofctl dump-flows $bridge | \
      grep -v -E "idle_timeout|hard_timeout" | wc -l
    
    sleep 300  # Check every 5 minutes
done
```

#### Flow Pattern Analysis
```bash
#!/bin/bash
# flow-pattern-analysis.sh

bridge="br-int"

echo "=== Flow Pattern Analysis ==="

# Analyze action patterns
echo "Most common actions:"
ovs-ofctl dump-flows $bridge | \
  grep -o "actions=[^,]*" | sort | uniq -c | sort -nr | head -10

# Analyze match patterns
echo -e "\nMost common match criteria:"
ovs-ofctl dump-flows $bridge | \
  grep -o -E "(tcp|udp|arp|icmp|in_port=[0-9]+)" | \
  sort | uniq -c | sort -nr | head -10

# Priority distribution
echo -e "\nPriority distribution:"
ovs-ofctl dump-flows $bridge | \
  grep -o "priority=[0-9]*" | sort | uniq -c | sort -k2 -nr | head -10
```

### Automated Flow Management

#### Dynamic Flow Updates
```bash
#!/bin/bash
# dynamic-flow-manager.sh

bridge="br-int"
config_file="/etc/ovs/dynamic-flows.conf"

# Function to update flows based on configuration
update_flows() {
    local config_file=$1
    
    if [ ! -f "$config_file" ]; then
        echo "Configuration file not found: $config_file"
        return 1
    fi
    
    echo "Updating flows from $config_file"
    
    # Read and apply flow configurations
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*# ]] || [[ -z $line ]]; then
            continue  # Skip comments and empty lines
        fi
        
        if [[ $line =~ ^ADD: ]]; then
            flow="${line#ADD: }"
            echo "Adding flow: $flow"
            ovs-ofctl add-flow $bridge "$flow"
        elif [[ $line =~ ^DEL: ]]; then
            flow="${line#DEL: }"
            echo "Deleting flow: $flow"
            ovs-ofctl del-flows $bridge "$flow"
        elif [[ $line =~ ^MOD: ]]; then
            flow="${line#MOD: }"
            echo "Modifying flow: $flow"
            ovs-ofctl mod-flows $bridge "$flow"
        fi
    done < "$config_file"
}

# Example configuration file format:
cat <<'EOF' > $config_file
# Dynamic flow configuration
# Format: ACTION: flow_specification

ADD: priority=1000,tcp,nw_dst=192.168.1.10,actions=output:2
MOD: priority=2000,arp,actions=flood
DEL: priority=500,tcp,tp_dst=22
EOF

# Apply configurations
update_flows $config_file
```

## Troubleshooting with ovs-ofctl

### Common Issues and Solutions

#### Flow Programming Issues
```bash
# Check for flow programming errors
ovs-ofctl dump-flows br-int | grep -i error

# Verify flow installation
ovs-appctl coverage/show | grep flow

# Check for flow table overflow
max_flows=$(ovs-vsctl get bridge br-int other_config:flow-limit)
current_flows=$(ovs-ofctl dump-flows br-int | wc -l)
echo "Flow utilization: $current_flows / $max_flows"
```

#### Performance Bottlenecks
```bash
# Identify high-CPU flows
ovs-ofctl dump-flows br-int | \
  grep -E "n_packets=[1-9][0-9]{6,}" | \
  head -10

# Check for excessive flow modifications
ovs-appctl coverage/show | grep -E "flow_mod|flow_extract"

# Monitor upcalls (controller interactions)
ovs-appctl upcall/show
```

#### Connectivity Debugging
```bash
#!/bin/bash
# comprehensive-debug.sh

bridge="br-int"
src_ip="192.168.1.10"
dst_ip="192.168.1.20"

echo "=== Comprehensive Connectivity Debug ==="

# 1. Check basic connectivity flows
echo "1. Basic connectivity flows:"
ovs-ofctl dump-flows $bridge | grep -E "$src_ip|$dst_ip" | head -5

# 2. Check for blocking rules
echo -e "\n2. Potential blocking rules:"
ovs-ofctl dump-flows $bridge | grep "actions=drop" | \
  grep -E "$src_ip|$dst_ip"

# 3. Trace packet path
echo -e "\n3. Packet trace:"
ovs-appctl ofproto/trace $bridge \
  "in_port(1),eth_type(0x0800),ipv4(src=$src_ip,dst=$dst_ip,proto=1),icmp(type=8,code=0)"

# 4. Check port status
echo -e "\n4. Port status:"
ovs-ofctl show $bridge | grep -A2 -B2 "addr"

# 5. Verify tunnel connectivity (if applicable)
echo -e "\n5. Tunnel status:"
ovs-vsctl show | grep -A5 "type: geneve"
```

## Best Practices

### Flow Management Guidelines

#### 1. **Use Appropriate Priorities**
```bash
# Security policies: 2000-3000
ovs-ofctl add-flow br-int priority=2500,tcp,tp_dst=22,actions=drop

# Normal forwarding: 1000-1999
ovs-ofctl add-flow br-int priority=1000,actions=normal

# Default policies: 0-999
ovs-ofctl add-flow br-int priority=0,actions=drop
```

#### 2. **Implement Flow Timeouts**
```bash
# Use idle timeouts for temporary flows
ovs-ofctl add-flow br-int \
  priority=1500,idle_timeout=300,tcp,actions=normal

# Use hard timeouts for time-limited policies
ovs-ofctl add-flow br-int \
  priority=2000,hard_timeout=3600,tcp,tp_dst=80,actions=output:2
```

#### 3. **Monitor Flow Table Utilization**
```bash
#!/bin/bash
# flow-table-monitoring.sh

bridge="br-int"
threshold=80  # Percentage threshold

current_flows=$(ovs-ofctl dump-flows $bridge | wc -l)
max_flows=$(ovs-vsctl get bridge $bridge other_config:flow-limit 2>/dev/null || echo "200000")

utilization=$((current_flows * 100 / max_flows))

if [ $utilization -gt $threshold ]; then
    echo "WARNING: Flow table utilization is ${utilization}%"
    echo "Consider flow optimization or increasing limits"
fi
```

### Performance Optimization

#### 1. **Optimize Flow Matching**
```bash
# Use specific matches to reduce lookup overhead
ovs-ofctl add-flow br-int \
  priority=1000,tcp,nw_dst=192.168.1.10,tp_dst=80,actions=output:2

# Avoid overly broad matches
# Bad: ovs-ofctl add-flow br-int priority=1000,actions=controller
# Good: ovs-ofctl add-flow br-int priority=1000,arp,actions=controller
```

#### 2. **Use Appropriate Table Structure**
```bash
# Distribute flows across multiple tables
ovs-ofctl add-flow br-int table=0,priority=1000,tcp,actions=resubmit(,1)
ovs-ofctl add-flow br-int table=1,priority=1000,nw_dst=192.168.1.0/24,actions=output:2
```

### Security Best Practices

#### 1. **Implement Defense in Depth**
```bash
# Multiple layers of security rules
ovs-ofctl add-flow br-int priority=3000,tcp,tp_dst=22,actions=drop
ovs-ofctl add-flow br-int priority=2500,tcp,nw_src=192.168.100.0/24,actions=drop
ovs-ofctl add-flow br-int priority=1000,tcp,actions=normal
```

#### 2. **Regular Security Audits**
```bash
#!/bin/bash
# security-audit.sh

bridge="br-int"

echo "=== Security Audit Report ==="

# Check for unrestricted access
echo "Flows with broad access:"
ovs-ofctl dump-flows $bridge | grep -E "actions=normal|flood" | \
  grep -v -E "tcp|udp|icmp" | head -5

# Check for default deny
echo -e "\nDefault deny policy:"
ovs-ofctl dump-flows $bridge | grep "priority=0.*drop"

# Review high-privilege flows
echo -e "\nHigh-priority flows:"
ovs-ofctl dump-flows $bridge | grep "priority=3[0-9][0-9][0-9]" | head -5
```

**ovs-ofctl** is an essential tool for managing and troubleshooting OpenFlow switches in OVN/OVS environments. Mastering its usage is crucial for effective network administration, debugging, and optimization in software-defined networking deployments.
