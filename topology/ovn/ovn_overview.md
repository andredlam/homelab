# Overview of OVN (Open Virtual Network)

## Topics

### What Is OVN?
OVN = Open Virtual Network
It’s a network virtualization system built on top of Open vSwitch (OVS). It provides logical networking abstractions — like virtual switches, routers, and firewalls — that are decoupled from the physical network.

### 🔧 Built for:
- OpenStack Neutron
- Kubernetes CNI
- Standalone SDN overlays
- L2 and L3 tenant isolation

### 🧱 High-Level Architecture
OVN splits responsibilities between three main planes:

|Plane | Component | Role|
|---|---|---|
|Control|ovn-northd|Converts high-level logical config → low-level config|
|Southbound|ovn-controller|Applies config to Open vSwitch on each node|
|Data|Open vSwitch|Forwards packets based on flow tables|


### 🔄 Component Workflow
#### 1. Northbound DB
- Contains logical network config: switches, routers, ACLs, ports, etc.
- Consumed by ovn-northd.

#### 2. ovn-northd
- Translates northbound config → southbound logical flows.
- Think of it as the compiler of OVN.

#### 3. Southbound DB
- Stores logical flows, port bindings, etc.
- Read by ovn-controller running on each hypervisor or gateway.

#### 4. ovn-controller
- **Each node’s ovn-controller reads southbound DB.**
- Converts logical flows → OpenFlow rules for OVS.
- **Maintains tunnels and updates OVS flow tables dynamically.**

#### 5. Open vSwitch (OVS)
- **Handles real-time packet forwarding.**
- **Uses OpenFlow and Geneve tunnels for encapsulation between hosts.**



### 📦 Logical Concepts
|OVN Object|Description|
|---|---|
|Logical Switch|Virtual L2 domain (like a VLAN or bridge)|
|Logical Router|Connects multiple logical switches (inter-subnet/L3 routing)|
|Logical Port|Connects a VM/container/interface to a switch|
|ACLs|Firewall rules|
|NAT/DHCP|Network services applied at the logical level|


### 🚀 How Packet Travels (Example)
1. VM on Host A sends a packet to another VM on Host B.
2. Packet hits logical switch and maybe a logical router.
3. OVN maps logical ports to physical host locations (via SBDB).
4. ovn-controller on Host A tells OVS to encapsulate the packet in Geneve.
5. Packet is sent over the overlay network (e.g., Geneve tunnel) to Host B.
6. ovn-controller on Host B decapsulates and delivers it to the target port.

### ⚙️ Integration with OpenStack
- OVN replaces the traditional Linux bridge + Neutron agents.
- Neutron API drives the northbound DB via ML2/OVN plugin.
- Dynamic port bindings, DHCP, NAT, and security groups handled logically.
- Great for scalability and fewer moving parts compared to legacy Neutron.

### 🧱 What Is a "Chassis"?
In OVN/OVS terms:
- A chassis = a host/node that runs:
    - openvswitch daemon (OVS)
    - ovn-controller process

- Each chassis is **registered in the OVN Southbound DB with its encapsulation IP, type (e.g., Geneve), and capabilities (e.g., gateway, bridge mappings).**

So when we say multi-chassis OVS, we mean multiple nodes, each running OVS and managed by OVN — forming a distributed virtual switching fabric.

Encapsulated with Geneve (Host to Host):
```
[Host A: 10.0.0.23] → [Host B: 10.0.0.24]
    └── [VM1: 192.168.1.10] → [VM2: 192.168.1.20]
```



### 🔄 How Multi-Chassis OVS Works
##### 1. Each Host Runs OVS and OVN-Controller
- Each node (hypervisor, gateway, or compute node) has its local OVS instance.
- ovn-controller on each node:
    - Connects to the OVN Southbound database (SBDB).
    - Reads logical flows.
    - Programs OpenFlow rules into OVS based on the logical-to-physical mappings.

#### 2. Logical Networking Across Nodes
- Logical switches and routers are abstracted from physical nodes.
- VMs/pods on different hosts can be connected to the same logical switch, even though they run on different physical nodes.
- OVN creates Geneve tunnels between chassis to carry traffic.

#### 3. Encapsulation and Tunneling
- When traffic is destined for a logical port on a different chassis:
    - The source node encapsulates the packet (Geneve, VXLAN).
    - Sends it over the physical network to the target chassis.
    - The receiving node decapsulates it and delivers it locally.

#### 4. Chassis in the Southbound DB
```bash
ovn-sbctl list chassis
```

Shows all participating chassis, including their:
- Tunnel IP (for Geneve overlay)
- Bridge mappings (e.g., br-ex → physical NIC)
- Whether it's a gateway chassis (used for external routing)

### 🛰️ Chassis as Gateways (Multi-Chassis L3 Gateway)
A multi-chassis gateway setup allows:
- Multiple chassis to act as external gateways (for SNAT, DNAT, floating IPs, etc.)
- OVN to use ECMP (Equal-Cost Multi-Path) or active-backup across multiple gateways

This solves:
- Single point of failure in north-south traffic
- Bottlenecks in L3 routing

Example:
```shell
ovn-nbctl set Logical_Router_Port lrp1 options:redirect-chassis=gateway1
```

You can also configure gateway groups for HA.

### 📦 Benefits of Multi-Chassis OVS
|Benefit|Description|
|---|---|
|Scalability|Each node processes its own traffic — no central bottleneck|
|High Availability|Multi-gateway chassis avoid single points of failure|
|Fault Isolation|Only one chassis affected during node failures|
|Efficient Routing|East-west traffic doesn't leave the node if destination is local|
|Tenant Isolation|Logical ports, ACLs, NAT, etc., enforced per chassis|

#### 🔧 Example: Packet Flow
VM A on Host 1 → VM B on Host 2:
1. VM A sends packet → hits br-int on Host 1
2. OVS matches OpenFlow rules → encapsulates using Geneve
3. Sends to Host 2’s tunnel interface
4. Host 2 decapsulates and forwards to VM B via br-int

OVN handles location awareness, encapsulation, and flow distribution using the Southbound DB and distributed control logic.


## br0, br-int, br-ex in Openstack

**br0** – General Purpose Bridge (Linux bridge or OVS)
- br0 is not OpenStack-specific, but commonly used when manually bridging a physical NIC to VMs.
- You’ll often see br0 in KVM, libvirt, or cloud-init networking.

**br-int** – Integration Bridge (Internal Open vSwitch Bridge)
- Managed by OVS and ovn-controller (or Neutron agent).
- Every VM’s virtual NIC (vNIC) gets attached here.
- Handles logical switching, security groups, and port bindings.

##### Example:
Incoming traffic from a VM lands on br-int.
- OVS rules/flows determine whether to:
    - Route internally to another VM
    - Forward to br-ex or tunnel to other compute nodes (via br-tun)
    - Apply ACLs, QoS, etc.


**br-ex** – External Bridge
- Bridges the OpenStack network to the physical world.
- Connected to a physical interface (e.g., eth0, ens3).
- Used for:
    - Floating IPs
    - External provider networks
    - Public internet access


# OVN-Controller-VTEP: Hardware VTEP Integration

### Overview

`ovn-controller-vtep` is a specialized OVN component that enables integration between OVN logical networks and hardware VTEP (VXLAN Tunnel Endpoint) devices. It acts as a bridge between OVN's software-defined networking and physical hardware switches that support VTEP functionality.

### Architecture and Role

```
┌────────────────────────────────────────────────────────────────────────────────────────────────┐
│                           OVN-CONTROLLER-VTEP ARCHITECTURE                                     │
│                                                                                                │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                            OVN CONTROL PLANE                                             │  │
│  │                                                                                          │  │
│  │  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                       │  │
│  │  │   OVN-Northd    │    │  Northbound DB  │    │  Southbound DB  │                       │  │
│  │  │                 │◄──►│                 │◄──►│                 │                       │  │
│  │  │ Logical Network │    │ Logical Config  │    │ Physical Config │                       │  │
│  │  │   Translation   │    │                 │    │                 │                       │  │
│  │  └─────────────────┘    └─────────────────┘    └─────────────────┘                       │  │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                             │                                                  │
│                                    Configuration Updates                                       │
│                                             │                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                         TRANSLATION LAYER                                                │  │
│  │                                                                                          │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │  │
│  │  │                      OVN-CONTROLLER-VTEP                                            │  │  │
│  │  │                                                                                     │  │  │
│  │  │  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                │  │  │
│  │  │  │  OVN Southbound │    │   Translation   │    │  OVSDB Hardware │                │  │  │
│  │  │  │  DB Monitor     │◄──►│     Engine      │◄──►│  VTEP Schema    │                │  │  │
│  │  │  │                 │    │                 │    │                 │                │  │  │
│  │  │  │ • Port Bindings │    │ • Logical→Phys  │    │ • Physical_Port │                │  │  │
│  │  │  │ • MAC Bindings  │    │ • MAC Learning  │    │ • Physical_Switch│               │  │  │
│  │  │  │ • Tunnel Keys   │    │ • Tunnel Mgmt   │    │ • Logical_Switch │               │  │  │
│  │  │  │ • Load Balancer │    │ • VTEP Binding  │    │ • Mcast_Remote  │                │  │  │
│  │  │  │ • ACL Rules     │    │ • Flow Rules    │    │ • Ucast_Remote  │                │  │  │
│  │  │  └─────────────────┘    └─────────────────┘    └─────────────────┘                │  │  │
│  │  │                                                                                     │  │  │
│  │  │  Functions:                                                                         │  │  │
│  │  │  • Monitors OVN SB-DB for logical network changes                                   │  │  │
│  │  │  • Translates OVN logical concepts to hardware VTEP schema                         │  │  │
│  │  │  • Manages MAC address learning between logical and physical domains               │  │  │
│  │  │  • Handles tunnel endpoint configuration                                            │  │  │
│  │  │  • Synchronizes multicast/broadcast groups                                          │  │  │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                             │                                                  │
│                                    OVSDB-Server Connection                                     │
│                                             │                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                         HARDWARE VTEP DEVICES                                           │  │
│  │                                                                                          │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │  │
│  │  │                      HARDWARE VTEP SWITCH                                           │  │  │
│  │  │                                                                                     │  │  │
│  │  │  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                │  │  │
│  │  │  │   OVSDB Server  │    │  VTEP Database  │    │ VXLAN Dataplane │                │  │  │
│  │  │  │                 │◄──►│                 │◄──►│                 │                │  │  │
│  │  │  │ • Hardware VTEP │    │ Schema Tables:  │    │ • Tunnel Terms  │                │  │  │
│  │  │  │   Schema        │    │ - Physical_Port │    │ • MAC Learning  │                │  │  │
│  │  │  │ • Configuration │    │ - Logical_Switch│    │ • Flooding      │                │  │  │
│  │  │  │   Management    │    │ - Mcast_Macs_*  │    │ • L2 Forwarding │                │  │  │
│  │  │  │ • Statistics    │    │ - Ucast_Macs_*  │    │ • VXLAN Encap   │                │  │  │
│  │  │  └─────────────────┘    └─────────────────┘    └─────────────────┘                │  │  │
│  │  │                                                                                     │  │  │
│  │  │  Physical Ports:      Tunnel Endpoints:         Logical Networks:                  │  │  │
│  │  │  ┌─────┐ ┌─────┐      ┌──────────────┐          ┌─────────────────┐               │  │  │
│  │  │  │Port1│ │Port2│      │VTEP IP:      │          │Logical Switch 1 │               │  │  │
│  │  │  │     │ │     │      │10.0.100.10   │          │VNI: 5001        │               │  │  │
│  │  │  │VLAN │ │VLAN │      │UDP: 4789     │          │                 │               │  │  │
│  │  │  │100  │ │200  │      └──────────────┘          │Logical Switch 2 │               │  │  │
│  │  │  └─────┘ └─────┘                                │VNI: 5002        │               │  │  │
│  │  │                                                 └─────────────────┘               │  │  │
│  │  └─────────────────────────────────────────────────────────────────────────────────────┘  │
│                                             │                                                  │
│                                      Physical Network                                          │
│                                             │                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                           COMPUTE NODES                                                 │  │
│  │                                                                                          │  │
│  │  ┌─────────────┐  ┌─────────────┐               ┌─────────────┐  ┌─────────────┐         │  │
│  │  │OVN-Controller│  │OVN-Controller│       ...     │OVN-Controller│  │   Virtual   │         │  │
│  │  │             │  │             │               │             │  │  Machines   │         │  │
│  │  │   Node 1    │  │   Node 2    │               │   Node N    │  │             │         │  │
│  │  │             │  │             │               │             │  │ ┌─────┐     │         │  │
│  │  │   OVS       │  │   OVS       │               │   OVS       │  │ │ VM1 │     │         │  │
│  │  │  Bridge     │  │  Bridge     │               │  Bridge     │  │ │     │     │         │  │
│  │  │             │  │             │               │             │  │ │ VM2 │     │         │  │
│  │  └─────────────┘  └─────────────┘               └─────────────┘  │ └─────┘     │         │  │
│  │        │                │                             │         └─────────────┘         │  │
│  │        └────────────────┼─────────────────────────────┘                                 │  │
│  │                         │                                                               │  │
│  │                  VXLAN Tunnels                                                          │  │
│  │                  (Software VTEP)                                                        │  │
│  └──────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                │
│  Integration Flow:                                                                             │
│  1. OVN creates logical networks in NB-DB                                                     │
│  2. OVN-Northd translates to SB-DB (port bindings, flows)                                     │
│  3. OVN-Controller-VTEP reads SB-DB and translates to Hardware VTEP schema                    │
│  4. Hardware VTEP switch programs dataplane based on VTEP database                            │
│  5. Traffic flows between VMs (via OVN) and physical devices (via Hardware VTEP)              │
│  6. MAC learning and tunnel management handled automatically                                   │
└────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Key Components and Functions

#### 1. Database Translation
`ovn-controller-vtep` performs bidirectional translation between two database schemas:

**OVN Southbound Schema** (Input):
- `Port_Binding` - Logical port to physical location mapping
- `MAC_Binding` - MAC address learning information
- `Encap` - Tunnel endpoint information
- `Datapath_Binding` - Logical switch to tunnel key mapping

**Hardware VTEP Schema** (Output):
- `Physical_Switch` - Physical switch identification
- `Physical_Port` - Physical port configuration
- `Logical_Switch` - VNI-based logical network definition
- `Ucast_Macs_Local/Remote` - Unicast MAC address tables
- `Mcast_Macs_Local/Remote` - Multicast/broadcast handling

#### 2. MAC Address Learning
The controller manages MAC address synchronization:

```bash
# Example MAC learning flow
OVN VM (MAC: aa:bb:cc:dd:ee:ff) → OVN Logical Switch → 
SB-DB MAC_Binding → ovn-controller-vtep → 
Hardware VTEP Ucast_Macs_Local → Physical Network
```

#### 3. Tunnel Management
Handles VXLAN tunnel establishment between software and hardware VTEPs:

- **VNI Assignment**: Maps OVN logical switches to VXLAN VNIs
- **Endpoint Discovery**: Synchronizes tunnel endpoints
- **Traffic Engineering**: Manages multicast groups for BUM traffic

### Installation and Configuration

#### Prerequisites
```bash
# Install OVN VTEP components
apt update
apt install -y ovn-vtep ovn-common

# Verify hardware VTEP switch supports OVSDB management
# Check vendor documentation for VTEP schema support
```

#### Basic Configuration

```bash
# 1. Configure Hardware VTEP Switch Database Connection
# On the hardware switch (via management interface):
vtep-switch-config --add-switch switch1 --tunnel-ip 10.0.100.10

# Enable OVSDB server on hardware switch
vtep-ovsdb-server --remote=ptcp:6640 --log-file

# 2. Configure ovn-controller-vtep on OVN control node
# Create VTEP configuration file
cat > /etc/ovn/vtep-config.conf << 'EOF'
# Hardware VTEP Database Connection
VTEP_DB="tcp:10.0.100.10:6640"

# OVN Southbound Database
OVN_SB_DB="tcp:10.0.1.10:6642,tcp:10.0.1.11:6642,tcp:10.0.1.12:6642"

# VTEP Switch Name (as configured on hardware)
VTEP_SWITCH="switch1"
EOF

# 3. Create systemd service for ovn-controller-vtep
cat > /etc/systemd/system/ovn-controller-vtep.service << 'EOF'
[Unit]
Description=OVN VTEP Controller
After=network.target ovn-northd.service
Wants=network.target

[Service]
Type=forking
Restart=always
RestartSec=5

# Load configuration
EnvironmentFile=/etc/ovn/vtep-config.conf

# Start ovn-controller-vtep
ExecStart=/usr/bin/ovn-controller-vtep \
    --vtep-db=${VTEP_DB} \
    --ovnsb-db=${OVN_SB_DB} \
    --log-file=/var/log/ovn/ovn-controller-vtep.log \
    --pidfile=/var/run/ovn/ovn-controller-vtep.pid \
    --detach

PIDFile=/var/run/ovn/ovn-controller-vtep.pid
User=ovn
Group=ovn

[Install]
WantedBy=multi-user.target
EOF

# 4. Enable and start the service
systemctl daemon-reload
systemctl enable ovn-controller-vtep
systemctl start ovn-controller-vtep
```

### Advanced Configuration Examples

#### Multi-VTEP Setup
```bash
# Configure multiple hardware VTEP switches
cat > /etc/ovn/multi-vtep.conf << 'EOF'
# Primary VTEP
VTEP1_DB="tcp:10.0.100.10:6640"
VTEP1_SWITCH="tor-switch-1"

# Secondary VTEP  
VTEP2_DB="tcp:10.0.100.11:6640"
VTEP2_SWITCH="tor-switch-2"

# OVN Configuration
OVN_SB_DB="tcp:10.0.1.10:6642,tcp:10.0.1.11:6642,tcp:10.0.1.12:6642"
EOF

# Start multiple controllers
/usr/bin/ovn-controller-vtep \
    --vtep-db=tcp:10.0.100.10:6640 \
    --ovnsb-db=${OVN_SB_DB} \
    --log-file=/var/log/ovn/vtep-1.log \
    --pidfile=/var/run/ovn/vtep-1.pid \
    --detach

/usr/bin/ovn-controller-vtep \
    --vtep-db=tcp:10.0.100.11:6640 \
    --ovnsb-db=${OVN_SB_DB} \
    --log-file=/var/log/ovn/vtep-2.log \
    --pidfile=/var/run/ovn/vtep-2.pid \
    --detach
```

#### VTEP Port Binding
```bash
# Bind physical ports to logical switches
# This is typically done through OVN northbound configuration

# Create logical switch for VTEP integration
ovn-nbctl ls-add vtep-ls-1

# Create logical switch port for VTEP binding
ovn-nbctl lsp-add vtep-ls-1 vtep-port-1
ovn-nbctl lsp-set-type vtep-port-1 vtep
ovn-nbctl lsp-set-options vtep-port-1 vtep-physical-switch=switch1 vtep-logical-switch=ls1

# The ovn-controller-vtep will automatically:
# 1. Create corresponding entries in hardware VTEP database
# 2. Configure VXLAN tunnels between OVN and hardware
# 3. Set up MAC learning between domains
```

### Operational Commands

#### Monitoring VTEP Integration
```bash
# Check ovn-controller-vtep status
systemctl status ovn-controller-vtep

# View VTEP controller logs  
tail -f /var/log/ovn/ovn-controller-vtep.log

# Check OVN southbound database for VTEP bindings
ovn-sbctl list Chassis
ovn-sbctl list Port_Binding | grep vtep

# Monitor hardware VTEP database
vtep-ctl --db=tcp:10.0.100.10:6640 list Physical_Switch
vtep-ctl --db=tcp:10.0.100.10:6640 list Logical_Switch
vtep-ctl --db=tcp:10.0.100.10:6640 list Ucast_Macs_Local
```

#### Troubleshooting Commands
```bash
# Debug VTEP database connectivity
ovn-controller-vtep --vtep-db=tcp:10.0.100.10:6640 --help

# Test hardware VTEP OVSDB connection
ovsdb-client --timeout=5 list-tables tcp:10.0.100.10:6640

# Check tunnel status
ovs-vsctl show
ovs-appctl fdb/show

# Verify VXLAN tunnel establishment
tcpdump -i any port 4789 -n

# MAC learning debugging
ovn-trace --detailed <logical_switch> 'inport=="vtep-port-1" && eth.src==aa:bb:cc:dd:ee:ff'
```

### Use Cases and Benefits

#### 1. Hybrid Cloud Integration
- Connect OVN virtual networks with physical ToR switches
- Seamless L2 extension between compute and bare-metal workloads
- Unified network policy across virtual and physical domains

#### 2. Legacy System Integration  
- Integrate existing physical infrastructure with OVN
- Gradual migration from physical to virtual networking
- Preserve existing VLAN-based network segments

#### 3. High-Performance Workloads
- Direct physical connectivity for performance-critical applications
- Hardware offload capabilities through physical switches
- Reduced overlay overhead for specific traffic patterns

#### 4. Multi-Tenant Environments
- Isolation between tenants using both virtual and physical resources
- Consistent security policies across deployment types
- Simplified network management for hybrid workloads

### Limitations and Considerations

1. **Hardware Dependency**: Requires switches with VTEP/OVSDB support
2. **Complexity**: Additional layer of translation and configuration
3. **Vendor Support**: Limited to switches supporting hardware VTEP schema
4. **Performance**: Translation overhead for database operations
5. **Troubleshooting**: More complex debugging across software/hardware boundary

`ovn-controller-vtep` is essential for environments requiring integration between OVN's software-defined networking and traditional hardware switching infrastructure, providing a bridge between these two domains while maintaining OVN's centralized control and policy management.