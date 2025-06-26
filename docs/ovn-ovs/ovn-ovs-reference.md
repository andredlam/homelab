# OVN/OVS Quick Reference Guide

## OVS (Open vSwitch) Commands

### Bridge Management
```bash
# List all bridges
ovs-vsctl list-br

# Create a bridge
ovs-vsctl add-br <bridge_name>

# Delete a bridge
ovs-vsctl del-br <bridge_name>

# Show bridge configuration
ovs-vsctl show

# List ports on a bridge
ovs-vsctl list-ports <bridge_name>
```

### Port Management
```bash
# Add port to bridge
ovs-vsctl add-port <bridge> <port>

# Add internal port
ovs-vsctl add-port <bridge> <port> -- set interface <port> type=internal

# Add VLAN tagged port
ovs-vsctl add-port <bridge> <port> tag=<vlan_id>

# Remove port
ovs-vsctl del-port <bridge> <port>

# Set port options
ovs-vsctl set port <port> <option>=<value>
ovs-vsctl set interface <interface> <option>=<value>
```

### Flow Management
```bash
# Show flow tables
ovs-ofctl dump-flows <bridge>

# Add flow rule
ovs-ofctl add-flow <bridge> "<match>,actions=<actions>"

# Delete flows
ovs-ofctl del-flows <bridge> [match]

# Modify flow
ovs-ofctl mod-flows <bridge> "<match>,actions=<actions>"

# Monitor flow additions/deletions
ovs-ofctl monitor <bridge> watch:
```

### Common Flow Examples
```bash
# Drop all ICMP traffic
ovs-ofctl add-flow br0 "icmp,actions=drop"

# Forward specific MAC to port
ovs-ofctl add-flow br0 "dl_dst=00:11:22:33:44:55,actions=output:1"

# VLAN stripping
ovs-ofctl add-flow br0 "dl_vlan=100,actions=strip_vlan,output:2"

# Rate limiting
ovs-ofctl add-flow br0 "actions=output:1" --max-rate=1000
```

### Debugging and Monitoring
```bash
# Show datapath flows
ovs-dpctl dump-flows

# Show port statistics
ovs-ofctl dump-ports <bridge>

# Show table statistics
ovs-ofctl dump-tables <bridge>

# Show group tables
ovs-ofctl dump-groups <bridge>

# Monitor packets
ovs-dpctl show

# Version information
ovs-vsctl --version
ovs-ofctl --version
```

## OVN (Open Virtual Network) Commands

### Northbound Database (Logical View)

#### Logical Switches
```bash
# List logical switches
ovn-nbctl ls-list

# Create logical switch
ovn-nbctl ls-add <switch_name>

# Delete logical switch
ovn-nbctl ls-del <switch_name>

# Show logical switch details
ovn-nbctl show <switch_name>
```

#### Logical Switch Ports
```bash
# Add logical switch port
ovn-nbctl lsp-add <switch> <port>

# Delete logical switch port
ovn-nbctl lsp-del <port>

# Set port addresses (MAC and/or IP)
ovn-nbctl lsp-set-addresses <port> "<mac> <ip>"
ovn-nbctl lsp-set-addresses <port> "dynamic"

# Set port type
ovn-nbctl lsp-set-type <port> <type>
# Types: router, localnet, localport, l2gateway, vtep

# Set port options
ovn-nbctl lsp-set-options <port> <key>=<value>

# List ports on switch
ovn-nbctl lsp-list <switch>
```

#### Logical Routers
```bash
# Create logical router
ovn-nbctl lr-add <router_name>

# Delete logical router
ovn-nbctl lr-del <router_name>

# List logical routers
ovn-nbctl lr-list

# Add router port
ovn-nbctl lrp-add <router> <port> <mac> <ip/mask>

# Delete router port
ovn-nbctl lrp-del <port>

# List router ports
ovn-nbctl lrp-list <router>
```

#### Static Routes
```bash
# Add static route
ovn-nbctl lr-route-add <router> <destination> <nexthop>

# Delete static route
ovn-nbctl lr-route-del <router> [destination]

# List routes
ovn-nbctl lr-route-list <router>
```

#### NAT Rules
```bash
# Add SNAT rule
ovn-nbctl lr-nat-add <router> snat <external_ip> <internal_ip>

# Add DNAT rule
ovn-nbctl lr-nat-add <router> dnat <external_ip> <internal_ip>

# Add DNAT_AND_SNAT (floating IP)
ovn-nbctl lr-nat-add <router> dnat_and_snat <external_ip> <internal_ip>

# List NAT rules
ovn-nbctl lr-nat-list <router>

# Delete NAT rule
ovn-nbctl lr-nat-del <router> <type> <external_ip>
```

#### ACLs (Access Control Lists)
```bash
# Add ACL rule
ovn-nbctl acl-add <switch> <direction> <priority> <match> <action>

# Directions: from-lport, to-lport
# Actions: allow, allow-related, drop, reject

# List ACLs
ovn-nbctl acl-list <switch>

# Delete ACL
ovn-nbctl acl-del <switch> [direction [priority [match]]]

# Examples:
ovn-nbctl acl-add ls1 from-lport 1000 'ip4.src==192.168.1.0/24' allow
ovn-nbctl acl-add ls1 to-lport 1000 'tcp.dst==80' allow
ovn-nbctl acl-add ls1 from-lport 900 'ip4' drop
```

#### DHCP
```bash
# Create DHCP options
ovn-nbctl dhcp-options-create <cidr>

# Set DHCP options
ovn-nbctl dhcp-options-set-options <dhcp_uuid> \
  lease_time=3600 router=192.168.1.1 server_id=192.168.1.1 \
  server_mac=02:00:00:00:01:00

# Apply DHCP to port
ovn-nbctl lsp-set-dhcpv4-options <port> <dhcp_uuid>

# List DHCP options
ovn-nbctl dhcp-options-list
```

### Southbound Database (Physical View)

#### Chassis Information
```bash
# List chassis (physical nodes)
ovn-sbctl list chassis

# Show chassis details
ovn-sbctl show

# List chassis by hostname
ovn-sbctl --columns=name,hostname list chassis
```

#### Port Bindings
```bash
# List port bindings
ovn-sbctl list port_binding

# Show specific port binding
ovn-sbctl find port_binding logical_port=<port_name>

# Show port bindings on chassis
ovn-sbctl --columns=logical_port,chassis find port_binding \
  chassis=<chassis_uuid>
```

#### Logical Flows
```bash
# Dump all logical flows
ovn-sbctl dump-flows

# Show flows for specific logical datapath
ovn-sbctl dump-flows <datapath_uuid>

# Show flows by table
ovn-sbctl dump-flows | grep "table="
```

### Database Management
```bash
# Northbound database backup
ovn-nbctl --db=<db_path> backup > nb_backup.db

# Southbound database backup
ovn-sbctl --db=<db_path> backup > sb_backup.db

# Set database connection
ovn-nbctl set-connection <connection_string>
ovn-sbctl set-connection <connection_string>

# Get database schema
ovn-nbctl get-schema
ovn-sbctl get-schema
```

## Troubleshooting Commands

### Packet Tracing
```bash
# Trace packet through logical network
ovn-trace [--detailed] <logical_datapath> '<packet_description>'

# Example: Trace ping from vm1 to vm2
ovn-trace --detailed subnet1 \
  'inport=="vm1" && eth.src==02:00:00:01:00:01 && \
   eth.dst==02:00:00:01:00:02 && ip4.src==192.168.1.10 && \
   ip4.dst==192.168.1.20 && icmp'
```

### Connection Testing
```bash
# Test northbound database connection
ovn-nbctl show

# Test southbound database connection
ovn-sbctl show

# Check OVN controller status
systemctl status ovn-controller

# Check OVS status
systemctl status openvswitch-switch
```

### Log Analysis
```bash
# OVN northbound logs
journalctl -u ovn-northd

# OVN controller logs
journalctl -u ovn-controller

# OVS logs
journalctl -u openvswitch-switch

# Real-time log monitoring
journalctl -fu ovn-controller
```

### Performance Monitoring
```bash
# OVS port statistics
ovs-ofctl dump-ports br-int

# OVN database statistics
ovn-nbctl --stats show
ovn-sbctl --stats show

# Flow table statistics
ovs-ofctl dump-tables br-int

# Coverage information
ovs-appctl coverage/show
```

## Common Troubleshooting Scenarios

### 1. VM Cannot Communicate
```bash
# Check port binding
ovn-sbctl find port_binding logical_port=<vm_port>

# Verify chassis registration
ovn-sbctl list chassis

# Check logical flows
ovn-trace <switch> '<packet_info>'

# Verify OVS interface binding
ovs-vsctl get interface <interface> external_ids
```

### 2. ACL Not Working
```bash
# Verify ACL syntax
ovn-nbctl acl-list <switch>

# Check priority order (higher number = higher priority)
# Verify match expressions

# Trace packet with ACL
ovn-trace --detailed <switch> '<packet_info>'
```

### 3. DHCP Issues
```bash
# Check DHCP options
ovn-nbctl dhcp-options-list

# Verify port DHCP assignment
ovn-nbctl lsp-get-dhcpv4-options <port>

# Monitor DHCP traffic
tcpdump -i any port 67 or port 68
```

### 4. Inter-subnet Routing Problems
```bash
# Check router configuration
ovn-nbctl lr-list
ovn-nbctl show <router>

# Verify router port configuration
ovn-nbctl lrp-list <router>

# Check routing table
ovn-nbctl lr-route-list <router>

# Trace inter-subnet packet
ovn-trace <source_switch> '<cross_subnet_packet>'
```

## Performance Tuning Tips

### OVS Optimization
```bash
# Enable megaflows
ovs-vsctl set Open_vSwitch . other_config:max-idle=10000

# Set flow eviction threshold
ovs-vsctl set bridge br-int other_config:flow-eviction-threshold=2500

# Configure datapath type (userspace or kernel)
ovs-vsctl set bridge br-int datapath_type=netdev
```

### OVN Optimization
```bash
# Enable logical flow caching
ovs-vsctl set open . external_ids:ovn-enable-lflow-cache=true

# Set encapsulation for performance
ovs-vsctl set open . external_ids:ovn-encap-type=geneve
```

## Security Best Practices

### ACL Security
```bash
# Default deny rule (lowest priority)
ovn-nbctl acl-add <switch> from-lport 1 'ip' drop
ovn-nbctl acl-add <switch> to-lport 1 'ip' drop

# Allow established connections
ovn-nbctl acl-add <switch> from-lport 1000 'ct.est' allow-related
ovn-nbctl acl-add <switch> to-lport 1000 'ct.est' allow-related

# Allow specific services
ovn-nbctl acl-add <switch> from-lport 900 'tcp.dst==22' allow
ovn-nbctl acl-add <switch> from-lport 900 'tcp.dst==80' allow
```

### Network Isolation
```bash
# Prevent inter-tenant communication
ovn-nbctl acl-add tenant1 from-lport 500 'ip4.dst==<tenant2_cidr>' drop
ovn-nbctl acl-add tenant2 from-lport 500 'ip4.dst==<tenant1_cidr>' drop
```

This reference guide should help you quickly find the right commands for common OVN/OVS operations and troubleshooting scenarios.
