# OVN/OVS Hands-On Lab Exercises

## Lab Environment Requirements

- Linux host (Ubuntu 20.04+ recommended)
- 4GB+ RAM, 20GB+ disk space
- Docker and Docker Compose (optional)
- Root/sudo access

## Lab 1: OVS Fundamentals

### Objective
Learn basic OVS operations, bridge management, and flow inspection.

### Setup
```bash
# Install OVS
sudo apt update
sudo apt install -y openvswitch-switch openvswitch-common

# Start OVS services
sudo systemctl start openvswitch-switch
sudo systemctl enable openvswitch-switch

# Verify installation
sudo ovs-vsctl show
```

### Exercise 1.1: Create Basic Bridge
```bash
# Create a bridge
sudo ovs-vsctl add-br br0

# Add a port to the bridge
sudo ovs-vsctl add-port br0 veth0 -- set interface veth0 type=internal

# Set IP on the internal interface
sudo ip addr add 192.168.100.1/24 dev veth0
sudo ip link set veth0 up

# Verify configuration
sudo ovs-vsctl show
sudo ovs-vsctl list bridge br0
```

### Exercise 1.2: Network Namespaces with OVS
```bash
# Create network namespaces
sudo ip netns add ns1
sudo ip netns add ns2

# Create veth pairs
sudo ip link add veth1 type veth peer name veth1-br
sudo ip link add veth2 type veth peer name veth2-br

# Move veth ends to namespaces
sudo ip link set veth1 netns ns1
sudo ip link set veth2 netns ns2

# Add bridge ends to OVS
sudo ovs-vsctl add-port br0 veth1-br
sudo ovs-vsctl add-port br0 veth2-br

# Configure interfaces in namespaces
sudo ip netns exec ns1 ip addr add 192.168.100.10/24 dev veth1
sudo ip netns exec ns1 ip link set veth1 up
sudo ip netns exec ns1 ip link set lo up

sudo ip netns exec ns2 ip addr add 192.168.100.20/24 dev veth2
sudo ip netns exec ns2 ip link set veth2 up
sudo ip netns exec ns2 ip link set lo up

# Bring up bridge interfaces
sudo ip link set veth1-br up
sudo ip link set veth2-br up

# Test connectivity
sudo ip netns exec ns1 ping -c 3 192.168.100.20
```

### Exercise 1.3: Flow Table Inspection
```bash
# View OpenFlow rules
sudo ovs-ofctl dump-flows br0

# Add a custom flow (drop ICMP)
sudo ovs-ofctl add-flow br0 "priority=100,icmp,actions=drop"

# Test that ping is blocked
sudo ip netns exec ns1 ping -c 3 192.168.100.20

# Remove the flow
sudo ovs-ofctl del-flows br0 "icmp"

# Verify ping works again
sudo ip netns exec ns1 ping -c 3 192.168.100.20
```

## Lab 2: VLAN Isolation

### Objective
Implement VLAN-based network isolation using OVS.

### Exercise 2.1: VLAN Configuration
```bash
# Create additional namespaces for different VLANs
sudo ip netns add vlan10-ns1
sudo ip netns add vlan10-ns2
sudo ip netns add vlan20-ns1
sudo ip netns add vlan20-ns2

# Create veth pairs
sudo ip link add vlan10-veth1 type veth peer name vlan10-veth1-br
sudo ip link add vlan10-veth2 type veth peer name vlan10-veth2-br
sudo ip link add vlan20-veth1 type veth peer name vlan20-veth1-br
sudo ip link add vlan20-veth2 type veth peer name vlan20-veth2-br

# Move to namespaces
sudo ip link set vlan10-veth1 netns vlan10-ns1
sudo ip link set vlan10-veth2 netns vlan10-ns2
sudo ip link set vlan20-veth1 netns vlan20-ns1
sudo ip link set vlan20-veth2 netns vlan20-ns2

# Add to OVS bridge with VLAN tags
sudo ovs-vsctl add-port br0 vlan10-veth1-br tag=10
sudo ovs-vsctl add-port br0 vlan10-veth2-br tag=10
sudo ovs-vsctl add-port br0 vlan20-veth1-br tag=20
sudo ovs-vsctl add-port br0 vlan20-veth2-br tag=20

# Configure IP addresses
sudo ip netns exec vlan10-ns1 ip addr add 192.168.10.1/24 dev vlan10-veth1
sudo ip netns exec vlan10-ns1 ip link set vlan10-veth1 up
sudo ip netns exec vlan10-ns1 ip link set lo up

sudo ip netns exec vlan10-ns2 ip addr add 192.168.10.2/24 dev vlan10-veth2
sudo ip netns exec vlan10-ns2 ip link set vlan10-veth2 up
sudo ip netns exec vlan10-ns2 ip link set lo up

sudo ip netns exec vlan20-ns1 ip addr add 192.168.20.1/24 dev vlan20-veth1
sudo ip netns exec vlan20-ns1 ip link set vlan20-veth1 up
sudo ip netns exec vlan20-ns1 ip link set lo up

sudo ip netns exec vlan20-ns2 ip addr add 192.168.20.2/24 dev vlan20-veth2
sudo ip netns exec vlan20-ns2 ip link set vlan20-veth2 up
sudo ip netns exec vlan20-ns2 ip link set lo up

# Bring up bridge interfaces
sudo ip link set vlan10-veth1-br up
sudo ip link set vlan10-veth2-br up
sudo ip link set vlan20-veth1-br up
sudo ip link set vlan20-veth2-br up

# Test VLAN isolation
echo "Testing VLAN 10 connectivity (should work):"
sudo ip netns exec vlan10-ns1 ping -c 3 192.168.10.2

echo "Testing VLAN 20 connectivity (should work):"
sudo ip netns exec vlan20-ns1 ping -c 3 192.168.20.2

echo "Testing cross-VLAN connectivity (should fail):"
sudo ip netns exec vlan10-ns1 ping -c 3 192.168.20.1
```

## Lab 3: OVN Basic Setup

### Objective
Set up OVN central services and create logical networks.

### Exercise 3.1: OVN Installation and Setup
```bash
# Install OVN
sudo apt install -y ovn-central ovn-host ovn-common

# Start OVN central services
sudo systemctl start ovn-central
sudo systemctl enable ovn-central

# Configure OVN to use local databases
sudo ovs-vsctl set open . external-ids:ovn-remote=unix:/var/run/ovn/ovnsb_db.sock
sudo ovs-vsctl set open . external-ids:ovn-encap-type=geneve
sudo ovs-vsctl set open . external-ids:ovn-encap-ip=127.0.0.1

# Start ovn-controller
sudo systemctl start ovn-controller
sudo systemctl enable ovn-controller

# Verify setup
sudo ovn-nbctl show
sudo ovn-sbctl show
```

### Exercise 3.2: Create Logical Network
```bash
# Create a logical switch
sudo ovn-nbctl ls-add switch1

# Create logical ports
sudo ovn-nbctl lsp-add switch1 port1
sudo ovn-nbctl lsp-add switch1 port2

# Set addresses for logical ports
sudo ovn-nbctl lsp-set-addresses port1 "02:00:00:00:00:01 192.168.1.10"
sudo ovn-nbctl lsp-set-addresses port2 "02:00:00:00:00:02 192.168.1.20"

# Create OVS ports and bind to logical ports
sudo ovs-vsctl add-port br-int veth-port1 -- set interface veth-port1 type=internal
sudo ovs-vsctl add-port br-int veth-port2 -- set interface veth-port2 type=internal

# Bind OVS interfaces to OVN logical ports
sudo ovs-vsctl set interface veth-port1 external_ids:iface-id=port1
sudo ovs-vsctl set interface veth-port2 external_ids:iface-id=port2

# Create namespaces and move interfaces
sudo ip netns add ovn-ns1
sudo ip netns add ovn-ns2

sudo ip link set veth-port1 netns ovn-ns1
sudo ip link set veth-port2 netns ovn-ns2

# Configure interfaces in namespaces
sudo ip netns exec ovn-ns1 ip link set veth-port1 address 02:00:00:00:00:01
sudo ip netns exec ovn-ns1 ip addr add 192.168.1.10/24 dev veth-port1
sudo ip netns exec ovn-ns1 ip link set veth-port1 up
sudo ip netns exec ovn-ns1 ip link set lo up

sudo ip netns exec ovn-ns2 ip link set veth-port2 address 02:00:00:00:00:02
sudo ip netns exec ovn-ns2 ip addr add 192.168.1.20/24 dev veth-port2
sudo ip netns exec ovn-ns2 ip link set veth-port2 up
sudo ip netns exec ovn-ns2 ip link set lo up

# Test connectivity
sudo ip netns exec ovn-ns1 ping -c 3 192.168.1.20
```

## Lab 4: OVN Logical Router

### Objective
Create logical routers for inter-subnet communication.

### Exercise 4.1: Multi-Subnet Setup with Router
```bash
# Create two logical switches for different subnets
sudo ovn-nbctl ls-add subnet1
sudo ovn-nbctl ls-add subnet2

# Create a logical router
sudo ovn-nbctl lr-add router1

# Create router ports for each subnet
sudo ovn-nbctl lrp-add router1 rp-subnet1 02:00:00:00:01:01 192.168.1.1/24
sudo ovn-nbctl lrp-add router1 rp-subnet2 02:00:00:00:02:01 192.168.2.1/24

# Connect switches to router
sudo ovn-nbctl lsp-add subnet1 subnet1-rp
sudo ovn-nbctl lsp-set-type subnet1-rp router
sudo ovn-nbctl lsp-set-addresses subnet1-rp router
sudo ovn-nbctl lsp-set-options subnet1-rp router-port=rp-subnet1

sudo ovn-nbctl lsp-add subnet2 subnet2-rp
sudo ovn-nbctl lsp-set-type subnet2-rp router
sudo ovn-nbctl lsp-set-addresses subnet2-rp router
sudo ovn-nbctl lsp-set-options subnet2-rp router-port=rp-subnet2

# Add logical ports to switches
sudo ovn-nbctl lsp-add subnet1 vm1
sudo ovn-nbctl lsp-set-addresses vm1 "02:00:00:01:00:01 192.168.1.10"

sudo ovn-nbctl lsp-add subnet1 vm2
sudo ovn-nbctl lsp-set-addresses vm2 "02:00:00:01:00:02 192.168.1.20"

sudo ovn-nbctl lsp-add subnet2 vm3
sudo ovn-nbctl lsp-set-addresses vm3 "02:00:00:02:00:01 192.168.2.10"

sudo ovn-nbctl lsp-add subnet2 vm4
sudo ovn-nbctl lsp-set-addresses vm4 "02:00:00:02:00:02 192.168.2.20"

# Create and configure VMs (network namespaces)
for i in 1 2 3 4; do
    sudo ip netns add vm$i
    sudo ovs-vsctl add-port br-int veth-vm$i -- set interface veth-vm$i type=internal
    sudo ovs-vsctl set interface veth-vm$i external_ids:iface-id=vm$i
    sudo ip link set veth-vm$i netns vm$i
    sudo ip netns exec vm$i ip link set lo up
done

# Configure VM1 (subnet1)
sudo ip netns exec vm1 ip link set veth-vm1 address 02:00:00:01:00:01
sudo ip netns exec vm1 ip addr add 192.168.1.10/24 dev veth-vm1
sudo ip netns exec vm1 ip route add default via 192.168.1.1
sudo ip netns exec vm1 ip link set veth-vm1 up

# Configure VM2 (subnet1)
sudo ip netns exec vm2 ip link set veth-vm2 address 02:00:00:01:00:02
sudo ip netns exec vm2 ip addr add 192.168.1.20/24 dev veth-vm2
sudo ip netns exec vm2 ip route add default via 192.168.1.1
sudo ip netns exec vm2 ip link set veth-vm2 up

# Configure VM3 (subnet2)
sudo ip netns exec vm3 ip link set veth-vm3 address 02:00:00:02:00:01
sudo ip netns exec vm3 ip addr add 192.168.2.10/24 dev veth-vm3
sudo ip netns exec vm3 ip route add default via 192.168.2.1
sudo ip netns exec vm3 ip link set veth-vm3 up

# Configure VM4 (subnet2)
sudo ip netns exec vm4 ip link set veth-vm4 address 02:00:00:02:00:02
sudo ip netns exec vm4 ip addr add 192.168.2.20/24 dev veth-vm4
sudo ip netns exec vm4 ip route add default via 192.168.2.1
sudo ip netns exec vm4 ip link set veth-vm4 up

# Test connectivity
echo "Testing same subnet connectivity:"
sudo ip netns exec vm1 ping -c 3 192.168.1.20

echo "Testing inter-subnet connectivity via router:"
sudo ip netns exec vm1 ping -c 3 192.168.2.10
```

## Lab 5: OVN ACLs (Firewall Rules)

### Objective
Implement security policies using OVN ACLs.

### Exercise 5.1: Basic ACL Rules
```bash
# Block ICMP between subnets (using setup from Lab 4)
sudo ovn-nbctl acl-add subnet1 from-lport 100 'ip4.dst == 192.168.2.0/24 && icmp' drop

# Test that ICMP is blocked
echo "Testing ICMP blocking (should fail):"
sudo ip netns exec vm1 ping -c 3 192.168.2.10

# Allow HTTP traffic between subnets
sudo ovn-nbctl acl-add subnet1 from-lport 90 'ip4.dst == 192.168.2.0/24 && tcp.dst == 80' allow

# Allow all other traffic within same subnet
sudo ovn-nbctl acl-add subnet1 from-lport 50 'ip4.dst == 192.168.1.0/24' allow
sudo ovn-nbctl acl-add subnet2 from-lport 50 'ip4.dst == 192.168.2.0/24' allow

# View ACL rules
sudo ovn-nbctl acl-list subnet1
sudo ovn-nbctl acl-list subnet2
```

## Lab 6: Cleanup Scripts

### Exercise 6.1: Complete Cleanup
```bash
#!/bin/bash
# cleanup-ovn-labs.sh

echo "Cleaning up OVN/OVS lab environment..."

# Remove network namespaces
for ns in ns1 ns2 vlan10-ns1 vlan10-ns2 vlan20-ns1 vlan20-ns2 ovn-ns1 ovn-ns2 vm1 vm2 vm3 vm4; do
    sudo ip netns del $ns 2>/dev/null || true
done

# Remove OVN logical components
sudo ovn-nbctl --if-exists lr-del router1
sudo ovn-nbctl --if-exists ls-del switch1
sudo ovn-nbctl --if-exists ls-del subnet1
sudo ovn-nbctl --if-exists ls-del subnet2

# Remove OVS bridges
sudo ovs-vsctl --if-exists del-br br0
sudo ovs-vsctl --if-exists del-br br-int

# Remove any remaining veth interfaces
for veth in veth0 veth1-br veth2-br vlan10-veth1-br vlan10-veth2-br vlan20-veth1-br vlan20-veth2-br; do
    sudo ip link del $veth 2>/dev/null || true
done

echo "Cleanup complete!"
```

## Troubleshooting Commands

### OVS Debugging
```bash
# View OVS configuration
sudo ovs-vsctl show

# Dump flow tables
sudo ovs-ofctl dump-flows br0
sudo ovs-ofctl dump-flows br-int

# Monitor traffic
sudo ovs-dpctl dump-flows

# View port statistics
sudo ovs-ofctl dump-ports br0
```

### OVN Debugging
```bash
# View logical network topology
sudo ovn-nbctl show

# View physical network state
sudo ovn-sbctl show

# Check logical flows
sudo ovn-sbctl dump-flows

# View chassis information
sudo ovn-sbctl list chassis

# Trace packet path
sudo ovn-trace --detailed subnet1 'inport=="vm1" && eth.src==02:00:00:01:00:01 && eth.dst==02:00:00:02:00:01 && ip4.src==192.168.1.10 && ip4.dst==192.168.2.10'
```

## Lab Results Verification

After each lab, verify:

1. **Connectivity**: Test expected communication paths
2. **Isolation**: Verify blocked traffic is actually blocked  
3. **Flow Tables**: Examine OpenFlow rules match your expectations
4. **Logical Topology**: Check OVN logical view matches physical reality
5. **Performance**: Basic throughput testing with iperf3

## Next Steps

- Experiment with load balancing features
- Try multi-chassis setups with multiple VMs/containers
- Integrate with container orchestrators (Docker, Kubernetes)
- Explore OVN integration with OpenStack
