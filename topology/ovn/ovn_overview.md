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