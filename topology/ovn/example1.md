# Example

### Example1: Mininet-Based OVN Lab (Single VM or Host)
```text

           +---------------------+
           |     OVN Central     |
           |  ovn-nb / ovn-sb    |
           +----------+----------+
                      |
         +------------+------------+
         |                         |
  +------+-------+         +-------+------+
  |   node1      |         |    node2     |
  | br-int + OVS |         | br-int + OVS |
  | veth1        |         | veth2        |
  +--------------+         +--------------+
```

```shell
sudo apt update
sudo apt install -y openvswitch-switch ovn-common ovn-central ovn-host mininet python3-pip

sudo mn --controller=remote,ip=127.0.0.1,port=6640 --switch=ovsk --topo=linear,2

This creates:
1 OVS switch (named s1)
2 Mininet hosts (h1, h2)


# Configure NB DB and SB DB to listen on TCP ports
sudo ovn-nbctl set-connection ptcp:6641
sudo ovn-sbctl set-connection ptcp:6642

# Check connections
ovn-nbctl get-connection
ovn-sbctl get-connection

# Create OVN logical switch
sudo ovn-nbctl ls-add ls0

# Create and bind ports for the Mininet hosts
sudo ovn-nbctl lsp-add ls0 lsp-h1
sudo ovn-nbctl lsp-set-addresses lsp-h1 "02:00:00:00:00:01 10.0.0.1"

sudo ovn-nbctl lsp-add ls0 lsp-h2
sudo ovn-nbctl lsp-set-addresses lsp-h2 "02:00:00:00:00:02 10.0.0.2"

# Bind OVS interfaces to OVN logical ports
sudo ovs-vsctl set Interface s1-eth1 external_ids:iface-id=lsp-h1
sudo ovs-vsctl set Interface s1-eth2 external_ids:iface-id=lsp-h2

mininet> h1 ping -c3 10.0.0.2

```

### Multi-VM OVN Lab (More Realistic)
```text
           +---------------------+
           |     OVN Central     |
           |  ovn-nb / ovn-sb    |
           +----------+----------+
                      |
         +------------+------------+
         |                         |
  +------+-------+         +-------+------+
  |   node1      |         |    node2     |
  | br-int + OVS |         | br-int + OVS |
  | veth1        |         | veth2        |
  +--------------+         +--------------+
```

```shell
--- Node-1 ---
sudo apt install -y openvswitch-switch ovn-central
sudo systemctl enable --now ovn-central

# Listen on TCP for SB/NB DBs
sudo ovn-nbctl set-connection ptcp:6641
sudo ovn-sbctl set-connection ptcp:6642


--- Both node-1 and node-2 ---
sudo apt install -y openvswitch-switch ovn-host
sudo systemctl enable --now ovn-controller

# Tell ovn-controller where to find OVN Central
sudo ovs-vsctl set Open_vSwitch . external_ids:ovn-remote=tcp:<node1-IP>:6642
sudo ovs-vsctl set Open_vSwitch . external_ids:ovn-encap-type=geneve
sudo ovs-vsctl set Open_vSwitch . external_ids:ovn-encap-ip=<local-IP>


--- Node-1 ---
# Verify chassis
sudo ovn-sbctl list chassis

# Create Logical Network
# On OVN Central node
sudo ovn-nbctl ls-add ls-test
sudo ovn-nbctl lsp-add ls-test port-node1
sudo ovn-nbctl lsp-set-addresses port-node1 "02:00:00:00:00:01 10.0.0.1"

sudo ovn-nbctl lsp-add ls-test port-node2
sudo ovn-nbctl lsp-set-addresses port-node2 "02:00:00:00:00:02 10.0.0.2"

--- Binding OVS Interfaces ---
# On node1
sudo ovs-vsctl add-port br-int veth-node1 -- set Interface veth-node1 external_ids:iface-id=port-node1

# On node2
sudo ovs-vsctl add-port br-int veth-node2 -- set Interface veth-node2 external_ids:iface-id=port-node2



```