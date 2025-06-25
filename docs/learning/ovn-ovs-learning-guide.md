# OVN/OVS Learning Guide

## Learning Path Overview

This guide provides a structured approach to learning Open Virtual Network (OVN) and Open vSwitch (OVS), building from basics to advanced concepts.

## Prerequisites

- Basic Linux networking knowledge (you already have this based on your `linux_network.md`)
- Understanding of virtualization concepts
- Familiarity with Docker/containers (helpful but not required)

## Phase 1: Foundation (Week 1-2)

### 1.1 Understanding Open vSwitch (OVS) Basics

**Theory:**
- What is OVS and why was it created?
- OVS architecture: ovsdb-server, ovs-vswitchd, kernel datapath
- Flow tables and OpenFlow concepts
- Bridges, ports, and interfaces

**Hands-on Labs:**
1. Install OVS and create basic bridges
2. Create virtual interfaces and connect them
3. Examine flow tables and add custom flows
4. Monitor traffic with ovs-dpctl and ovs-ofctl

### 1.2 OVS Deep Dive

**Theory:**
- OpenFlow pipeline and flow matching
- Actions: output, set_field, goto_table, etc.
- VLAN tagging and tunneling (VXLAN, GRE, Geneve)
- Quality of Service (QoS) and policing

**Hands-on Labs:**
1. Create VLAN-based isolation
2. Set up VXLAN tunnels between hosts
3. Implement traffic shaping and QoS
4. Debug flows and troubleshoot connectivity

## Phase 2: Open Virtual Network (Week 3-4)

### 2.1 OVN Architecture

**Theory:**
- OVN components: ovn-northd, ovn-controller, databases
- Northbound vs Southbound APIs
- Logical vs Physical concepts
- Chassis and encapsulation

**Hands-on Labs:**
1. Set up OVN central services
2. Create logical switches and ports
3. Connect multiple chassis
4. Examine database contents

### 2.2 OVN Logical Networking

**Theory:**
- Logical switches (L2 domains)
- Logical routers (L3 routing)
- ACLs and security groups
- DHCP and DNS services
- NAT and load balancing

**Hands-on Labs:**
1. Create multi-tenant logical networks
2. Implement inter-subnet routing
3. Configure distributed firewalls
4. Set up NAT and floating IPs

## Phase 3: Advanced Concepts (Week 5-6)

### 3.1 Integration and Orchestration

**Theory:**
- OVN with OpenStack Neutron
- OVN with Kubernetes (ovn-kubernetes CNI)
- OVN with Docker/Podman
- Performance tuning and optimization

**Hands-on Labs:**
1. Deploy OVN with a container orchestrator
2. Implement service mesh networking
3. Performance testing and monitoring
4. Troubleshooting common issues

### 3.2 Production Considerations

**Theory:**
- High availability and clustering
- Monitoring and observability
- Security best practices
- Upgrade strategies

**Hands-on Labs:**
1. Set up HA OVN deployment
2. Implement monitoring with Prometheus
3. Security hardening
4. Disaster recovery procedures

## Recommended Resources

### Books
- "Open vSwitch: Up and Running" by Ben Pfaff (OVS creator)
- "Software Defined Networks: A Systems Approach" by Peterson et al.

### Online Resources
- OVN/OVS Official Documentation: https://docs.ovn.org/
- OVS Deep Dives: https://blog.russellbryant.net/
- Red Hat OpenStack Network Guide
- Kubernetes Network Policy Deep Dive

### Video Series
- OVN/OVS Conference Talks on YouTube
- Red Hat OpenStack Platform networking videos
- CNCF Kubernetes networking sessions

## Practical Exercises

### Exercise 1: Basic OVS Lab
**Goal:** Create a simple network with two VMs connected via OVS
**Skills:** Bridge creation, port management, flow inspection

### Exercise 2: Multi-host OVS
**Goal:** Connect VMs across physical hosts using VXLAN tunnels
**Skills:** Tunnel configuration, distributed switching

### Exercise 3: OVN Logical Networks
**Goal:** Create logical switches and routers with OVN
**Skills:** OVN northbound API, logical networking concepts

### Exercise 4: Service Integration
**Goal:** Integrate OVN with container platform
**Skills:** CNI integration, service discovery, load balancing

### Exercise 5: Production Deployment
**Goal:** Deploy highly available OVN cluster
**Skills:** Clustering, monitoring, troubleshooting

## Assessment Checklist

By the end of this learning path, you should be able to:

- [ ] Explain the difference between OVS and OVN
- [ ] Create and manage OVS bridges and flows
- [ ] Design logical network topologies with OVN
- [ ] Troubleshoot connectivity issues
- [ ] Integrate OVN with orchestration platforms
- [ ] Deploy production-ready OVN clusters
- [ ] Implement network security policies
- [ ] Monitor and optimize network performance

## Next Steps

After completing this learning path:
1. Contribute to OVN/OVS open source projects
2. Explore advanced topics like SR-IOV and hardware offloading
3. Study integration with emerging technologies (eBPF, service mesh)
4. Consider OVN/OVS certification programs

## Lab Environment Setup

Refer to your existing documentation in:
- `topology/ovn/simulator/` - For containerized lab setup
- `topology/ovn/example1.md` - For Mininet-based labs
- `topology/ovn/commands.md` - For command reference

## Additional Practice Ideas

1. **Network Function Virtualization (NFV)**: Use OVN to implement virtual firewalls, load balancers
2. **Multi-tenancy**: Create isolated networks for different applications
3. **Hybrid Cloud**: Connect on-premise OVN to cloud provider networks
4. **Edge Computing**: Deploy OVN in edge locations with limited resources
5. **CI/CD Integration**: Automate network testing with OVN in pipelines
