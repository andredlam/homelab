# VM Migration in OVN/OVS

VM migration in OVN/OVS environments involves updating port bindings and flow tables to ensure seamless network connectivity as VMs move between chassis (physical hosts).

## Migration Process Overview

### 1. **Pre-Migration State**
```bash
# VM running on chassis-1
ovn-sbctl find port_binding logical_port=vm1-port
# Output: chassis=chassis-1-uuid, tunnel_key=1

# Traffic flows normally to chassis-1
ovn-sbctl dump-flows | grep vm1-port
```

### 2. **During Migration**
The migration process involves several coordinated steps:

**Step 1: Destination Preparation**
- Hypervisor on destination chassis prepares VM environment
- Memory and disk state begin transferring
- Network interfaces remain on source chassis

**Step 2: Port Binding Update**
```bash
# ovn-controller on destination chassis detects new VM interface
# Updates port binding in Southbound DB
ovn-sbctl set port_binding vm1-port chassis=chassis-2-uuid

# Flow tables update automatically across all chassis
ovn-sbctl dump-flows | grep tunnel_key=1
```

**Step 3: Traffic Redirection**
- OVN updates logical flows to point to new chassis
- Tunnel endpoints change from chassis-1 to chassis-2
- Existing connections may experience brief interruption

### 3. **Post-Migration State**
```bash
# VM now running on chassis-2
ovn-sbctl find port_binding logical_port=vm1-port
# Output: chassis=chassis-2-uuid, tunnel_key=1 (same tunnel key)

# All traffic now flows to chassis-2
```

## Detailed Migration Mechanics

### **Port Binding Updates**
```bash
# Before migration
ovn-sbctl list port_binding vm1-port
# chassis: chassis-1-uuid
# tunnel_key: 5
# mac: ["52:54:00:12:34:56 192.168.1.10"]

# During migration (atomic update)
# ovn-controller on new chassis claims the port
ovn-sbctl set port_binding vm1-port chassis=chassis-2-uuid

# After migration
ovn-sbctl list port_binding vm1-port
# chassis: chassis-2-uuid
# tunnel_key: 5 (unchanged)
# mac: ["52:54:00:12:34:56 192.168.1.10"] (unchanged)
```

### **Flow Table Updates**
When port binding changes, ovn-controller on all chassis updates OpenFlow rules:

```bash
# On source chassis (chassis-1) - flows removed
ovs-ofctl dump-flows br-int | grep "tunnel_key=5"
# (no matching flows after migration)

# On destination chassis (chassis-2) - flows added
ovs-ofctl dump-flows br-int | grep "tunnel_key=5"
# Actions include local delivery to VM interface

# On other chassis - tunnel destination updated
ovs-ofctl dump-flows br-int | grep "tunnel_key=5"
# Actions point to chassis-2's tunnel IP
```

## Migration Types and Handling

### **1. Live Migration**
For minimal downtime:
```bash
# Migration with connection preservation
# 1. Memory transfer while VM runs
# 2. Brief pause for final state sync
# 3. Port binding update (atomic)
# 4. Resume on destination

# Network impact: ~100ms interruption
```

### **2. Cold Migration**
For maintenance scenarios:
```bash
# Migration with VM shutdown
# 1. VM shutdown on source
# 2. Port binding cleared
# 3. VM started on destination
# 4. Port binding established

# Network impact: Full downtime during migration
```

## OVN Components During Migration

### **ovn-northd Role**
- Processes port binding changes from Southbound DB
- Updates logical flows for new chassis location
- Maintains consistency across the cluster

### **ovn-controller Role**
```bash
# On source chassis
# 1. Detects VM interface removal
# 2. Removes local flows
# 3. Updates port binding (unbind)

# On destination chassis  
# 1. Detects new VM interface
# 2. Claims port binding
# 3. Installs local flows
# 4. Updates tunnel destinations
```

## Network Connectivity During Migration

### **East-West Traffic** (VM to VM)
```bash
# Before migration: VM1(chassis-1) → VM2(chassis-3)
# Packet flow: chassis-1 → tunnel → chassis-3

# During migration: Port binding updates
# Brief moment where packets may be dropped

# After migration: VM1(chassis-2) → VM2(chassis-3)  
# Packet flow: chassis-2 → tunnel → chassis-3
```

### **North-South Traffic** (VM to External)
```bash
# Gateway chassis handling remains unchanged
# Only source chassis for VM changes
# External connectivity maintained through gateway
```

## Monitoring VM Migration

### **Pre-Migration Checks**
```bash
# Verify current port binding
ovn-sbctl find port_binding logical_port=vm1-port

# Check current flows
ovn-sbctl dump-flows | grep vm1-port

# Monitor chassis status
ovn-sbctl list chassis
```

### **During Migration Monitoring**
```bash
# Watch port binding changes
watch "ovn-sbctl --columns=logical_port,chassis find port_binding logical_port=vm1-port"

# Monitor flow updates
watch "ovn-sbctl dump-flows | grep tunnel_key=5"

# Check connectivity
ping -c 1 192.168.1.10  # VM's IP address
```

### **Post-Migration Verification**
```bash
# Verify new port binding
ovn-sbctl get port_binding vm1-port chassis

# Test connectivity
kubectl exec -it test-pod -- ping 192.168.1.10

# Check flow consistency
ovn-sbctl dump-flows | grep vm1-port
```

## Migration Challenges and Solutions

### **1. Connection State Preservation**
```bash
# Challenge: TCP connections may break
# Solution: Use connection tracking and state migration
# OVS maintains connection state during brief interruption
```

### **2. ARP/MAC Learning**
```bash
# Challenge: Other VMs may have stale ARP entries
# Solution: Gratuitous ARP after migration
ip link set dev eth0 up
arping -A -c 3 -I eth0 192.168.1.10
```

### **3. Timing Synchronization**
```bash
# Challenge: Port binding updates must be atomic
# Solution: Database transactions ensure consistency
# ovn-controller uses proper locking mechanisms
```

## Best Practices for VM Migration

### **1. Migration Planning**
```bash
# Check resource availability on destination
free -h
df -h

# Verify network connectivity between chassis
ping destination-chassis-ip

# Ensure OVN services are healthy
systemctl status ovn-controller
```

### **2. Monitoring and Alerting**
```bash
# Set up monitoring for migration events
#!/bin/bash
# migration-monitor.sh
while true; do
    ovn-sbctl --columns=logical_port,chassis list port_binding | \
    grep -E "(vm1-port|vm2-port)" | \
    logger -t "ovn-migration"
    sleep 5
done
```

### **3. Rollback Procedures**
```bash
# In case of migration failure
# 1. Stop destination VM
# 2. Clear port binding
# 3. Restart source VM
# 4. Verify connectivity restored

ovn-sbctl clear port_binding vm1-port chassis
```

## Integration with Orchestration Systems

### **OpenStack Nova**
```bash
# Nova handles OVN port binding updates automatically
# During live migration:
# 1. Nova calls Neutron API
# 2. Neutron updates OVN Northbound DB
# 3. ovn-northd processes changes
# 4. Port bindings update in Southbound DB
```

### **Kubernetes/OpenShift**
```bash
# Pod migration (reschedule) in OVN-Kubernetes
# 1. Pod deleted on source node
# 2. New pod scheduled on destination
# 3. CNI plugin updates OVN port binding
# 4. Network connectivity established
```

## Advanced Migration Scenarios

### **Multi-Network Migration**
```bash
# VM with multiple network interfaces
# Each logical port must be migrated independently
ovn-sbctl find port_binding | grep vm1
# vm1-port-net1: chassis=chassis-2-uuid
# vm1-port-net2: chassis=chassis-2-uuid
# vm1-port-mgmt: chassis=chassis-2-uuid
```

### **Cross-Cluster Migration**
```bash
# Migration between different OVN clusters
# Requires external orchestration and network bridging
# 1. Create logical port in destination cluster
# 2. Establish temporary tunnel between clusters
# 3. Migrate VM and update port bindings
# 4. Remove temporary connectivity
```

### **High Availability During Migration**
```bash
# Use gateway chassis for external connectivity
# Multiple chassis can handle north-south traffic
ovn-nbctl set logical_router_port lrp1 \
  options:redirect-chassis="chassis1,chassis2,chassis3"

# Ensures external connectivity during migration
```

## Troubleshooting Migration Issues

### **Port Binding Failures**
```bash
# Check ovn-controller status on both chassis
systemctl status ovn-controller

# Verify database connectivity
ovn-sbctl show

# Check chassis registration
ovn-sbctl list chassis | grep -A5 -B5 chassis-name
```

### **Flow Programming Issues**
```bash
# Check for flow programming errors
ovs-ofctl dump-flows br-int | grep error

# Verify tunnel connectivity
ovs-vsctl show | grep -A10 tunnel

# Test tunnel reachability
ping tunnel-remote-ip
```

### **Performance Impact**
```bash
# Monitor migration performance
# Check memory transfer rate
virsh domjobinfo vm-name

# Monitor network impact
iftop -i tunnel-interface

# Check CPU usage during migration
top -p $(pgrep qemu)
```

## Security Considerations

### **Network Isolation During Migration**
```bash
# Ensure security groups/ACLs remain enforced
ovn-nbctl list acl | grep vm1-port

# Verify network policies are maintained
ovn-sbctl dump-flows | grep "priority=.*vm1"
```

### **Encryption in Transit**
```bash
# Use encrypted tunnels for sensitive workloads
ovs-vsctl set Interface genev_sys_6081 \
  options:key=flow options:remote_ip=flow \
  options:csum=true options:tos=inherit
```

VM migration in OVN/OVS is designed to be as seamless as possible, with automatic flow updates and minimal network interruption. The distributed nature of OVN ensures that migration events are handled efficiently across the entire cluster while maintaining network connectivity and security policies.
