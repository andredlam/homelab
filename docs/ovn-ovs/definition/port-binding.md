# Terminology and Definition

## Port Binding in OVN (Open Virtual Network)

**Port binding** is a critical concept in OVN that establishes the association between logical ports (abstract network interfaces) and their physical locations in the distributed network infrastructure.

### What is Port Binding?

Port binding in OVN is the process of mapping:
- **Logical ports** (abstract network interfaces defined in the Northbound DB)
- **Physical locations** (specific chassis/hosts where VMs or containers actually run)

This mapping is stored in the **Southbound Database** and is essential for OVN to know where to deliver packets in the distributed network.

### Key Components of Port Binding

1. **Logical Port**: The abstract network interface (e.g., a VM's network interface)
2. **Chassis**: The physical host/hypervisor where the workload runs
3. **Port Binding Record**: The database entry that links them together

### Port Binding States

Port bindings can be in different states:

| State | Description |
|-------|-------------|
| **Unbound** | Logical port exists but isn't assigned to any chassis |
| **Bound** | Logical port is active and assigned to a specific chassis |
| **Claimed** | Port is being claimed by a chassis (transitional state) |

### How Port Binding Works

#### 1. **Port Creation**
```bash
# Create a logical port (in Northbound DB)
ovn-nbctl lsp-add switch1 vm1-port
ovn-nbctl lsp-set-addresses vm1-port "50:54:00:00:00:01 192.168.1.10"
```

#### 2. **Port Binding Process**
When a VM starts on a chassis:
1. **ovn-controller** on the chassis detects the new interface
2. It creates a **port binding** in the Southbound DB
3. The logical port becomes "bound" to that specific chassis

#### 3. **Viewing Port Bindings**
```bash
# List all port bindings
ovn-sbctl list port_binding

# Show specific port binding details
ovn-sbctl find port_binding logical_port=vm1-port

# Show port bindings on a specific chassis
ovn-sbctl --columns=logical_port,chassis find port_binding \
  chassis=chassis-uuid
```

### Port Binding Database Schema

A port binding record contains:
```bash
# Example port binding record
logical_port    : "vm1-port"
chassis         : chassis-uuid
datapath        : datapath-uuid  
tunnel_key      : 1
type           : ""
options        : {}
mac            : ["50:54:00:00:00:01 192.168.1.10"]
```

### Types of Port Bindings

#### 1. **Regular VM/Container Ports**
- Standard logical ports bound to VMs or containers
- Most common type of port binding

#### 2. **Gateway Ports**
- Ports on logical routers that provide external connectivity
- Can be bound to gateway chassis

#### 3. **Localnet Ports**
- Ports that connect to physical networks
- Usually bound to chassis with physical network access

#### 4. **Patch Ports**
- Internal ports connecting logical switches to routers
- Don't require chassis binding

### Port Binding in Multi-Chassis Environment

In a distributed OVN deployment:

```bash
# Example: VM migration scenario
# Before migration (VM on chassis-1)
ovn-sbctl find port_binding logical_port=vm1-port
# chassis: chassis-1-uuid

# After migration (VM moved to chassis-2)  
ovn-sbctl find port_binding logical_port=vm1-port
# chassis: chassis-2-uuid
```

### Practical Examples

#### Check Port Binding Status
```bash
# List all port bindings with their chassis
ovn-sbctl --format=table --columns=logical_port,chassis,type list port_binding

# Find unbound ports
ovn-sbctl --columns=logical_port find port_binding chassis=[]

# Check if a specific port is bound
ovn-sbctl get port_binding vm1-port chassis
```

#### Troubleshooting Port Binding Issues
```bash
# Check if ovn-controller is running on chassis
systemctl status ovn-controller

# Check ovn-controller logs
journalctl -u ovn-controller -f

# Verify chassis registration
ovn-sbctl list chassis

# Check port binding consistency
ovn-nbctl list logical_switch_port vm1-port
ovn-sbctl list port_binding vm1-port
```

### Port Binding and Packet Flow

When a packet needs to be delivered:

1. **Source chassis** looks up the destination logical port
2. **Southbound DB** provides the port binding information
3. **Destination chassis** is identified from the binding
4. **Tunnel encapsulation** (Geneve/VXLAN) is used to reach the destination
5. **Destination chassis** decapsulates and delivers to the bound port

### Common Port Binding Scenarios

#### VM Migration
```bash
# During live migration, port binding updates automatically
# Old chassis: binding removed
# New chassis: binding created
# Network connectivity maintained through the process
```

#### Container Orchestration (Kubernetes)
```bash
# When a pod is scheduled:
# 1. CNI plugin creates logical port
# 2. ovn-controller binds port to node
# 3. Pod gets network connectivity
```

#### High Availability
```bash
# Gateway ports can be bound to multiple chassis
# for redundancy and load balancing
ovn-nbctl set logical_router_port lrp1 \
  options:redirect-chassis="chassis1,chassis2"
```

### Monitoring Port Bindings

```bash
# Script to monitor port binding changes
#!/bin/bash
watch -n 2 'ovn-sbctl --format=table \
  --columns=logical_port,chassis,type \
  list port_binding | grep -v "^$"'
```

## Summary

Port binding is fundamental to OVN's distributed architecture, enabling the system to maintain logical network abstractions while tracking the physical locations of network endpoints across multiple chassis in the infrastructure.

Key takeaways:
- Port bindings map logical ports to physical chassis locations
- They are essential for packet delivery in distributed OVN deployments
- Different types of ports (VM, gateway, localnet, patch) have different binding behaviors
- Proper monitoring and troubleshooting of port bindings is crucial for network operations
- Port bindings enable advanced features like VM migration and high availability