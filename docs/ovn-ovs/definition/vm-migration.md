# VM Migration in OVN/OVS

## Table of Contents

1. [Migration Process Overview](#migration-process-overview)
   - [Pre-Migration State](#1-pre-migration-state)
   - [During Migration](#2-during-migration)
   - [Post-Migration State](#3-post-migration-state)
2. [Detailed Migration Mechanics](#detailed-migration-mechanics)
   - [Port Binding Updates](#port-binding-updates)
   - [Flow Table Updates](#flow-table-updates)
3. [Migration Types and Handling](#migration-types-and-handling)
   - [Live Migration](#1-live-migration)
   - [Cold Migration](#2-cold-migration)
4. [OVN Components During Migration](#ovn-components-during-migration)
   - [ovn-northd Role](#ovn-northd-role)
   - [ovn-controller Role](#ovn-controller-role)
5. [Network Connectivity During Migration](#network-connectivity-during-migration)
   - [East-West Traffic](#east-west-traffic-vm-to-vm)
   - [North-South Traffic](#north-south-traffic-vm-to-external)
6. [VM Migration Process Diagram](#vm-migration-process-diagram)
7. [Migration Timeline and Performance Metrics](#migration-timeline-and-performance-metrics)
   - [Migration Performance Benchmarks](#migration-performance-benchmarks)
   - [Real-time Migration Monitoring](#real-time-migration-monitoring)
8. [Advanced Migration Techniques](#advanced-migration-techniques)
   - [Predictive Migration](#predictive-migration)
   - [Batch Migration for Maintenance](#batch-migration-for-maintenance)
9. [Migration Optimization Strategies](#migration-optimization-strategies)
   - [Memory Transfer Optimization](#memory-transfer-optimization)
   - [Network Impact Minimization](#network-impact-minimization)
10. [Migration Security and Compliance](#migration-security-and-compliance)
    - [Encrypted Migration](#encrypted-migration)
    - [Migration Auditing](#migration-auditing)
11. [Migration Testing and Validation](#migration-testing-and-validation)
    - [Automated Migration Testing](#automated-migration-testing)
    - [Stress Testing](#stress-testing)
12. [Monitoring VM Migration](#monitoring-vm-migration)
    - [Pre-Migration Checks](#pre-migration-checks)
    - [During Migration Monitoring](#during-migration-monitoring)
    - [Post-Migration Verification](#post-migration-verification)
13. [Migration Challenges and Solutions](#migration-challenges-and-solutions)
    - [Connection State Preservation](#1-connection-state-preservation)
    - [ARP/MAC Learning](#2-arpmac-learning)
    - [Timing Synchronization](#3-timing-synchronization)
14. [Best Practices for VM Migration](#best-practices-for-vm-migration)
    - [Migration Planning](#1-migration-planning)
    - [Monitoring and Alerting](#2-monitoring-and-alerting)
    - [Rollback Procedures](#3-rollback-procedures)
15. [Integration with Orchestration Systems](#integration-with-orchestration-systems)
    - [OpenStack Nova](#openstack-nova)
    - [Kubernetes/OpenShift](#kubernetesopenshift)
16. [Advanced Migration Scenarios](#advanced-migration-scenarios)
    - [Multi-Network Migration](#multi-network-migration)
    - [Cross-Cluster Migration](#cross-cluster-migration)
    - [High Availability During Migration](#high-availability-during-migration)
17. [Troubleshooting Migration Issues](#troubleshooting-migration-issues)
    - [Port Binding Failures](#port-binding-failures)
    - [Flow Programming Issues](#flow-programming-issues)
    - [Performance Impact](#performance-impact)
18. [Security Considerations](#security-considerations)
    - [Network Isolation During Migration](#network-isolation-during-migration)
    - [Encryption in Transit](#encryption-in-transit)

---

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

## VM Migration Process Diagram

```
                              VM MIGRATION IN OVN/OVS ENVIRONMENT
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 PRE-MIGRATION STATE                                             │
│                                                                                                 │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                               OVN CONTROL PLANE                                           │  │
│  │  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                        │  │
│  │  │   NB Database   │    │   ovn-northd    │    │   SB Database   │                        │  │
│  │  │                 │◄──►│                 │◄──►│                 │                        │  │
│  │  │ Logical Switch  │    │   Translates    │    │ Port Bindings   │                        │  │
│  │  │ Logical Ports   │    │   NB → SB       │    │ Chassis Info    │                        │  │
│  │  └─────────────────┘    └─────────────────┘    └─────────────────┘                        │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                             │                                                   │
│                                    Southbound Protocol                                          │
│                                             │                                                   │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                                 DATA PLANE                                                │  │
│  │                                                                                           │  │
│  │     CHASSIS-1 (Source)                           CHASSIS-2 (Destination)                  │  │
│  │  ┌─────────────────────────┐                  ┌─────────────────────────┐                 │  │
│  │  │    ovn-controller       │                  │    ovn-controller       │                 │  │
│  │  │                         │                  │                         │                 │  │
│  │  │  ┌─────────────────┐    │                  │  ┌─────────────────┐    │                 │  │
│  │  │  │      OVS        │    │                  │  │      OVS        │    │                 │  │
│  │  │  │    br-int       │    │                  │  │    br-int       │    │                 │  │
│  │  │  │                 │    │                  │  │                 │    │                 │  │
│  │  │  │ ┌─────────────┐ │    │                  │  │ ┌─────────────┐ │    │                 │  │
│  │  │  │ │    VM1      │ │    │                  │  │ │             │ │    │                 │  │
│  │  │  │ │ RUNNING     │ │    │                  │  │ │   EMPTY     │ │    │                 │  │
│  │  │  │ │ Port: vm1   │ │    │   Geneve Tunnel  │  │ │             │ │    │                 │  │
│  │  │  │ │ MAC: 52:54  │ │    │◄────────────────►│  │ │             │ │    │                 │  │
│  │  │  │ │ IP: 10.1.1.5│ │    │                  │  │ │             │ │    │                 │  │
│  │  │  │ └─────────────┘ │    │                  │  │ └─────────────┘ │    │                 │  │
│  │  │  └─────────────────┘    │                  │  └─────────────────┘    │                 │  │
│  │  └─────────────────────────┘                  └─────────────────────────┘                 │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                 │
│  Port Binding State:                                                                            │
│  vm1-port → chassis: chassis-1-uuid, tunnel_key: 5, mac: "52:54:00:12:34:56 10.1.1.5"           │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘

                                              ▼
                                    MIGRATION PROCESS
                                              ▼

┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                  DURING MIGRATION                                               │
│                                                                                                 │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                               OVN CONTROL PLANE                                           │  │
│  │  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                        │  │
│  │  │   NB Database   │    │   ovn-northd    │    │   SB Database   │                        │  │
│  │  │                 │◄──►│                 │◄──►│                 │                        │  │
│  │  │ Logical Switch  │    │   Processes     │    │ Port Binding    │                        │  │
│  │  │ (unchanged)     │    │   Updates       │    │ ⚠️ UPDATING ⚠️ │                        │  │
│  │  └─────────────────┘    └─────────────────┘    └─────────────────┘                        │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                             │                                                   │
│                                Flow Updates Propagating                                         │
│                                             │                                                   │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                                 DATA PLANE                                                │  │
│  │                                                                                           │  │
│  │     CHASSIS-1 (Source)                           CHASSIS-2 (Destination)                  │  │
│  │  ┌─────────────────────────┐                  ┌─────────────────────────┐                 │  │
│  │  │    ovn-controller       │                  │    ovn-controller       │                 │  │
│  │  │    ⚠️ UPDATING ⚠️      │                  │    ⚠️ UPDATING ⚠️      │                 │  │
│  │  │  ┌─────────────────┐    │                  │  ┌─────────────────┐    │                 │  │
│  │  │  │      OVS        │    │                  │  │      OVS        │    │                 │  │
│  │  │  │ Flows Removing  │    │                  │  │ Flows Installing│    │                 │  │
│  │  │  │                 │    │                  │  │                 │    │                 │  │
│  │  │  │ ┌─────────────┐ │    │    VM Memory     │  │ ┌─────────────┐ │    │                 │  │
│  │  │  │ │    VM1      │ │    │    Transfer      │  │ │    VM1      │ │    │                 │  │
│  │  │  │ │  PAUSING    │ │    │ ═══════════════► │  │ │ STARTING    │ │    │                 │  │
│  │  │  │ │             │ │    │                  │  │ │ Port: vm1   │ │    │                 │  │
│  │  │  │ │             │ │    │                  │  │ │ MAC: 52:54  │ │    │                 │  │
│  │  │  │ │             │ │    │                  │  │ │ IP: 10.1.1.5│ │    │                 │  │
│  │  │  │ └─────────────┘ │    │                  │  │ └─────────────┘ │    │                 │  │
│  │  │  └─────────────────┘    │                  │  └─────────────────┘    │                 │  │
│  │  └─────────────────────────┘                  └─────────────────────────┘                 │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                 │
│  Migration Steps:                                                                               │
│  1. Memory transfer begins                   4. Port binding updated atomically                 │
│  2. VM paused on source                      5. Flows updated on all chassis                    │
│  3. Final memory sync                        6. VM resumed on destination                       │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘

                                              ▼
                                    MIGRATION COMPLETE
                                              ▼

┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 POST-MIGRATION STATE                                            │
│                                                                                                 │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                               OVN CONTROL PLANE                                           │  │
│  │  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                        │  │
│  │  │   NB Database   │    │   ovn-northd    │    │   SB Database   │                        │  │
│  │  │                 │◄──►│                 │◄──►│                 │                        │  │
│  │  │ Logical Switch  │    │   Normal Ops    │    │ Port Bindings   │                        │  │
│  │  │ Logical Ports   │    │                 │    │ ✅ UPDATED      │                        │  │
│  │  └─────────────────┘    └─────────────────┘    └─────────────────┘                        │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                             │                                                   │
│                                    Stable Operations                                            │
│                                             │                                                   │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                                 DATA PLANE                                                │  │
│  │                                                                                           │  │
│  │     CHASSIS-1 (Source)                           CHASSIS-2 (Destination)                  │  │
│  │  ┌─────────────────────────┐                  ┌─────────────────────────┐                 │  │
│  │  │    ovn-controller       │                  │    ovn-controller       │                 │  │
│  │  │                         │                  │                         │                 │  │
│  │  │  ┌─────────────────┐    │                  │  ┌─────────────────┐    │                 │  │
│  │  │  │      OVS        │    │                  │  │      OVS        │    │                 │  │
│  │  │  │    br-int       │    │                  │  │    br-int       │    │                 │  │
│  │  │  │                 │    │                  │  │                 │    │                 │  │
│  │  │  │ ┌─────────────┐ │    │                  │  │ ┌─────────────┐ │    │                 │  │
│  │  │  │ │             │ │    │                  │  │ │    VM1      │ │    │                 │  │
│  │  │  │ │   EMPTY     │ │    │                  │  │ │ RUNNING     │ │    │                 │  │
│  │  │  │ │             │ │    │   Geneve Tunnel  │  │ │ Port: vm1   │ │    │                 │  │
│  │  │  │ │             │ │    │◄────────────────►│  │ │ MAC: 52:54  │ │    │                 │  │
│  │  │  │ │             │ │    │                  │  │ │ IP: 10.1.1.5│ │    │                 │  │
│  │  │  │ └─────────────┘ │    │                  │  │ └─────────────┘ │    │                 │  │
│  │  │  └─────────────────┘    │                  │  └─────────────────┘    │                 │  │
│  │  └─────────────────────────┘                  └─────────────────────────┘                 │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                 │
│  Port Binding State:                                                                            │
│  vm1-port → chassis: chassis-2-uuid, tunnel_key: 5, mac: "52:54:00:12:34:56 10.1.1.5"           │
│                                                                                                 │
│  ✅ Migration Complete:                                                                        │
│  • Same tunnel_key maintained (5)                                                               │
│  • Same MAC/IP addresses preserved                                                              │
│  • All traffic now flows to chassis-2                                                           │
│  • Network connectivity fully restored                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘

                              TRAFFIC FLOW DURING MIGRATION

┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                            EAST-WEST TRAFFIC (VM-to-VM)                                         │
│                                                                                                 │
│  Before Migration:                          During Migration:                                   │
│  ┌─────────────┐     Tunnel      ┌─────────────┐   ┌─────────────┐  ⚠️ Brief    ┌─────────────┐ │
│  │    VM1      │ ══════════════► │    VM2      │   │    VM1      │  Disruption  │    VM2      │ │
│  │ (chassis-1) │    VNI: 100     │ (chassis-3) │   │ (migrating) │     ~100ms   │ (chassis-3) │ │
│  └─────────────┘                 └─────────────┘   └─────────────┘              └─────────────┘ │
│                                                                                                 │
│  After Migration:                                                                               │
│  ┌─────────────┐     Tunnel      ┌─────────────┐                                                │
│  │    VM1      │ ══════════════► │    VM2      │                                                │
│  │ (chassis-2) │    VNI: 100     │ (chassis-3) │                                                │
│  └─────────────┘                 └─────────────┘                                                │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                           NORTH-SOUTH TRAFFIC (VM-to-External)                                  │
│                                                                                                 │
│  Before Migration:                          During Migration:                                   │
│  ┌─────────────┐     Tunnel      ┌─────────────┐   ┌─────────────┐   Gateway    ┌─────────────┐ │
│  │    VM1      │ ══════════════► │   Gateway   │   │    VM1      │ ═══════════► │   Gateway   │ │
│  │ (chassis-1) │                 │  Chassis    │   │ (migrating) │              │  Chassis    │ │
│  └─────────────┘                 └─────────────┘   └─────────────┘              └─────────────┘ │
│                                         │                               │               │       │
│                                         ▼                               ▼               ▼       │
│                                  ┌─────────────┐                 ┌─────────────┐ ┌─────────────┐│
│                                  │  External   │                 │  External   │ │  External   ││
│                                  │   Network   │                 │   Network   │ │   Network   ││
│                                  └─────────────┘                 └─────────────┘ └─────────────┘│
│                                                                                                 │
│  After Migration:                                                                               │
│  ┌─────────────┐     Tunnel      ┌─────────────┐                                                │
│  │    VM1      │ ══════════════► │   Gateway   │                                                │
│  │ (chassis-2) │                 │  Chassis    │                                                │
│  └─────────────┘                 └─────────────┘                                                │
│                                         │                                                       │
│                                         ▼                                                       │
│                                  ┌─────────────┐                                                │
│                                  │  External   │                                                │
│                                  │   Network   │                                                │
│                                  └─────────────┘                                                │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘

Key Migration Characteristics:
• Tunnel Key Preservation: VM keeps same tunnel_key (5) throughout migration
• MAC/IP Persistence: Network identity remains unchanged
• Atomic Updates: Port binding changes are atomic in SB database
• Flow Consistency: OVN ensures all chassis update flows consistently
• Minimal Downtime: Typical interruption is 50-200ms for live migration
• Connection Recovery: TCP connections can survive brief interruption

## Migration Timeline and Performance Metrics

### **Migration Performance Benchmarks**

```bash
# Typical Migration Timelines (Live Migration)
# Small VM (1GB RAM):     200-500ms downtime
# Medium VM (4GB RAM):    500ms-1s downtime  
# Large VM (16GB RAM):    1-3s downtime
# XL VM (64GB RAM):       3-10s downtime

# Factors affecting migration time:
# - Memory size and dirty page rate
# - Network bandwidth between chassis
# - CPU load on source/destination
# - Storage I/O patterns
```

### **Real-time Migration Monitoring**

```bash
#!/bin/bash
# migration-performance-monitor.sh
# Monitor migration performance in real-time

LOGICAL_PORT="vm1-port"
INTERVAL=0.1

echo "=== VM Migration Performance Monitor ==="
echo "Monitoring port: $LOGICAL_PORT"
echo "Timestamp,Chassis,Tunnel_Key,Status"

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    
    # Get current port binding
    BINDING=$(ovn-sbctl --format=csv --no-headings \
        --columns=chassis,tunnel_key \
        find port_binding logical_port="$LOGICAL_PORT")
    
    if [[ -n "$BINDING" ]]; then
        CHASSIS=$(echo "$BINDING" | cut -d',' -f1)
        TUNNEL_KEY=$(echo "$BINDING" | cut -d',' -f2)
        
        # Check if chassis is changing (migration in progress)
        if [[ "$CHASSIS" != "$PREV_CHASSIS" ]]; then
            if [[ -n "$PREV_CHASSIS" ]]; then
                echo "$TIMESTAMP,$CHASSIS,$TUNNEL_KEY,MIGRATION_DETECTED"
            else
                echo "$TIMESTAMP,$CHASSIS,$TUNNEL_KEY,INITIAL_STATE"
            fi
        fi
        
        PREV_CHASSIS="$CHASSIS"
    else
        echo "$TIMESTAMP,UNBOUND,N/A,PORT_UNBOUND"
    fi
    
    sleep $INTERVAL
done
```

## Advanced Migration Techniques

### **Predictive Migration**

```bash
# Proactive migration based on resource metrics
#!/bin/bash
# predictive-migration.sh

monitor_chassis_health() {
    local chassis=$1
    local cpu_threshold=80
    local mem_threshold=90
    
    # Get chassis resource utilization
    cpu_usage=$(ssh "$chassis" "top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d'%' -f1")
    mem_usage=$(ssh "$chassis" "free | grep Mem | awk '{printf \"%.0f\", \$3/\$2 * 100.0}'")
    
    if (( $(echo "$cpu_usage > $cpu_threshold" | bc -l) )) || \
       (( $(echo "$mem_usage > $mem_threshold" | bc -l) )); then
        echo "WARNING: Chassis $chassis overloaded (CPU: ${cpu_usage}%, MEM: ${mem_usage}%)"
        return 1
    fi
    return 0
}

# Trigger migration for overloaded chassis
migrate_vms_from_overloaded_chassis() {
    local source_chassis=$1
    
    # Find VMs on overloaded chassis
    ovn-sbctl --format=csv --no-headings \
        --columns=logical_port \
        find port_binding chassis="$source_chassis" | \
    while IFS= read -r logical_port; do
        # Find least loaded destination chassis
        target_chassis=$(find_least_loaded_chassis)
        
        echo "Migrating $logical_port from $source_chassis to $target_chassis"
        # Trigger migration through orchestrator API
        # This would be OpenStack Nova, Kubernetes, etc.
    done
}
```

### **Batch Migration for Maintenance**

```bash
# Efficient batch migration for chassis maintenance
#!/bin/bash
# maintenance-migration.sh

maintenance_migrate_chassis() {
    local chassis_name=$1
    local max_concurrent=3
    local current_migrations=0
    
    echo "=== Starting maintenance migration for $chassis_name ==="
    
    # Get all VMs on the chassis
    vm_list=$(ovn-sbctl --format=csv --no-headings \
        --columns=logical_port \
        find port_binding chassis="$chassis_name")
    
    # Calculate optimal migration order (smallest VMs first)
    vm_list_ordered=$(echo "$vm_list" | while read vm; do
        # Get VM memory size (this would need integration with hypervisor)
        mem_size=$(get_vm_memory_size "$vm")
        echo "$mem_size:$vm"
    done | sort -n | cut -d':' -f2)
    
    # Migrate VMs in batches
    echo "$vm_list_ordered" | while read logical_port; do
        if [[ $current_migrations -ge $max_concurrent ]]; then
            # Wait for a migration to complete
            wait_for_migration_slot
            ((current_migrations--))
        fi
        
        # Start migration
        echo "Starting migration of $logical_port"
        migrate_vm_async "$logical_port" &
        ((current_migrations++))
        
        # Brief delay to stagger migrations
        sleep 5
    done
    
    # Wait for all migrations to complete
    wait
    echo "=== All migrations completed for $chassis_name ==="
}
```

## Migration Optimization Strategies

### **Memory Transfer Optimization**

```bash
# Optimize memory transfer for large VMs
configure_migration_optimization() {
    cat > /etc/libvirt/qemu.conf << 'EOF'
# Migration performance tuning
migration_bandwidth_burst = 0        # Unlimited burst
migration_bandwidth = 1000          # 1Gbps sustained
migration_compression = "xbzrle"     # Enable compression
migration_downtime_limit = 500       # 500ms max downtime
migration_cancel_timeout = 180       # 3 min timeout

# For OVN environments
migration_parallel_connections = 4   # Parallel streams
migration_tls_force = 0             # TLS overhead consideration
EOF

    systemctl restart libvirtd
}

# Monitor migration bandwidth usage
monitor_migration_bandwidth() {
    local source_host=$1
    local dest_host=$2
    
    echo "=== Migration Bandwidth Monitor ==="
    
    # Monitor network interface on migration network
    while true; do
        rx_bytes=$(ssh "$dest_host" "cat /sys/class/net/eth1/statistics/rx_bytes")
        tx_bytes=$(ssh "$source_host" "cat /sys/class/net/eth1/statistics/tx_bytes")
        
        sleep 1
        
        rx_bytes_new=$(ssh "$dest_host" "cat /sys/class/net/eth1/statistics/rx_bytes")
        tx_bytes_new=$(ssh "$source_host" "cat /sys/class/net/eth1/statistics/tx_bytes")
        
        rx_rate=$(( (rx_bytes_new - rx_bytes) * 8 / 1024 / 1024 ))  # Mbps
        tx_rate=$(( (tx_bytes_new - tx_bytes) * 8 / 1024 / 1024 ))  # Mbps
        
        echo "$(date): Migration traffic - RX: ${rx_rate}Mbps, TX: ${tx_rate}Mbps"
    done
}
```

### **Network Impact Minimization**

```bash
# Implement gradual cutover to minimize network impact
gradual_migration_cutover() {
    local logical_port=$1
    local old_chassis=$2
    local new_chassis=$3
    
    echo "=== Implementing gradual cutover for $logical_port ==="
    
    # Phase 1: Announce new location (both chassis active)
    echo "Phase 1: Announcing new location"
    # This requires custom OVN modifications or external orchestration
    
    # Phase 2: Gradual traffic shift (weighted routing)
    echo "Phase 2: Gradual traffic shift"
    for weight in 10 25 50 75 90 100; do
        echo "Shifting ${weight}% of traffic to new chassis"
        # Implement weighted routing through external load balancer
        # or custom OVN flow modifications
        sleep 10
    done
    
    # Phase 3: Complete cutover
    echo "Phase 3: Complete cutover"
    ovn-sbctl set port_binding "$logical_port" chassis="$new_chassis"
    
    # Phase 4: Cleanup old location
    echo "Phase 4: Cleanup"
    sleep 30  # Grace period
    # Remove any remaining flows on old chassis
}
```

## Migration Security and Compliance

### **Encrypted Migration**

```bash
# Configure encrypted migration for sensitive workloads
setup_encrypted_migration() {
    cat > /etc/libvirt/migration-tls.conf << 'EOF'
# TLS configuration for secure migration
listen_tls = 1
listen_tcp = 0
auth_tls = "sasl"
tls_no_verify_certificate = 0

# Certificate paths
ca_file = "/etc/pki/CA/cacert.pem"
cert_file = "/etc/pki/libvirt/servercert.pem"
key_file = "/etc/pki/libvirt/private/serverkey.pem"
EOF

    # Generate migration certificates
    generate_migration_certificates
    
    # Restart services
    systemctl restart libvirtd
}

# Audit migration events
audit_migration() {
    local logical_port=$1
    local source_chassis=$2
    local dest_chassis=$3
    
    # Log migration event
    logger -t "ovn-migration-audit" \
        "MIGRATION: port=$logical_port, source=$source_chassis, dest=$dest_chassis, user=$(whoami), time=$(date -Iseconds)"
    
    # Send to SIEM/audit system
    curl -X POST "$AUDIT_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "{
            \"event\": \"vm_migration\",
            \"logical_port\": \"$logical_port\",
            \"source_chassis\": \"$source_chassis\",
            \"destination_chassis\": \"$dest_chassis\",
            \"timestamp\": \"$(date -Iseconds)\",
            \"operator\": \"$(whoami)\"
        }"
}
```

## Migration Testing and Validation

### **Automated Migration Testing**

```bash
#!/bin/bash
# migration-test-suite.sh
# Comprehensive migration testing framework

run_migration_test_suite() {
    local test_vm="test-migration-vm"
    local source_chassis="chassis-1"
    local dest_chassis="chassis-2"
    
    echo "=== Starting Migration Test Suite ==="
    
    # Test 1: Basic connectivity test
    test_basic_migration() {
        echo "Test 1: Basic Migration"
        
        # Verify pre-migration connectivity
        ping_test "$test_vm" || { echo "FAIL: Pre-migration connectivity"; return 1; }
        
        # Perform migration
        migrate_vm "$test_vm" "$source_chassis" "$dest_chassis"
        
        # Verify post-migration connectivity
        sleep 5
        ping_test "$test_vm" || { echo "FAIL: Post-migration connectivity"; return 1; }
        
        echo "PASS: Basic Migration"
    }
    
    # Test 2: TCP connection persistence
    test_tcp_persistence() {
        echo "Test 2: TCP Connection Persistence"
        
        # Establish long-running TCP connection
        start_tcp_session "$test_vm" &
        tcp_pid=$!
        
        sleep 2
        
        # Migrate during active connection
        migrate_vm "$test_vm" "$dest_chassis" "$source_chassis"
        
        # Check if connection survived
        if kill -0 $tcp_pid 2>/dev/null; then
            echo "PASS: TCP Connection Persistence"
            kill $tcp_pid
        else
            echo "FAIL: TCP Connection Persistence"
        fi
    }
    
    # Test 3: Performance impact measurement
    test_performance_impact() {
        echo "Test 3: Performance Impact"
        
        # Start performance monitoring
        start_performance_monitor "$test_vm" &
        monitor_pid=$!
        
        # Perform migration
        migration_start_time=$(date +%s.%N)
        migrate_vm "$test_vm" "$source_chassis" "$dest_chassis"
        migration_end_time=$(date +%s.%N)
        
        # Calculate downtime
        downtime=$(echo "$migration_end_time - $migration_start_time" | bc)
        
        kill $monitor_pid
        
        echo "Migration completed in: ${downtime}s"
        if (( $(echo "$downtime < 1.0" | bc -l) )); then
            echo "PASS: Performance Impact (<1s)"
        else
            echo "FAIL: Performance Impact (>1s)"
        fi
    }
    
    # Run all tests
    test_basic_migration
    test_tcp_persistence  
    test_performance_impact
    
    echo "=== Migration Test Suite Complete ==="
}

# Stress testing with multiple concurrent migrations
stress_test_migrations() {
    local num_vms=10
    local max_concurrent=3
    
    echo "=== Starting Migration Stress Test ==="
    
    # Create test VMs
    for i in $(seq 1 $num_vms); do
        create_test_vm "stress-vm-$i"
    done
    
    # Perform concurrent migrations
    for i in $(seq 1 $num_vms); do
        if (( $(jobs -r | wc -l) >= max_concurrent )); then
            wait -n  # Wait for any job to complete
        fi
        
        migrate_vm "stress-vm-$i" "chassis-1" "chassis-2" &
    done
    
    wait  # Wait for all migrations to complete
    
    # Cleanup
    for i in $(seq 1 $num_vms); do
        cleanup_test_vm "stress-vm-$i"
    done
    
    echo "=== Migration Stress Test Complete ==="
}
```
