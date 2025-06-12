## L3 gateway, floating IPs, NAT

```shell
VM (10.0.0.10) ──┬── Logical Switch (private)    name: ls-private
                 │
          Logical Router                         name: lr-router, has dnat/snat rules, default route
                 │                               
         Provider Network (public)               name: ls-public
                 │
              Internet                          

- SNAT: VM's internal IP (10.0.0.10) to public IP (e.g. 203.0.113.100)
- DNAT/Floating IP: Route public IP → VM
- Gateway: Route traffic outside OVN
```

### Configuration Steps
```shell
- Private subnet: 10.0.0.0/24
- Public (provider) subnet: 203.0.113.0/24
- Floating IP: 203.0.113.100
- VM internal IP: 10.0.0.10
- External bridge: br-ex

# Create logical switch and router
ovn-nbctl ls-add ls-private
ovn-nbctl lr-add lr-router

# Connect Logical Switch to Router
# Router Port
ovn-nbctl lrp-add lr-router lrp-private 00:00:00:00:01:01 10.0.0.1/24

# Switch Port
ovn-nbctl lsp-add ls-private lsp-private
ovn-nbctl lsp-set-type lsp-private router
ovn-nbctl lsp-set-addresses lsp-private router
ovn-nbctl lsp-set-options lsp-private router-port=lrp-private
ovn-nbctl lsp-set-port-security lsp-private 00:00:00:00:01:01

# Add External Network
ovn-nbctl ls-add ls-public

# External Port to bridge (br-ex)
ovn-nbctl lsp-add ls-public provnet-port
ovn-nbctl lsp-set-type provnet-port localnet
ovn-nbctl lsp-set-addresses provnet-port unknown
ovn-nbctl lsp-set-options provnet-port network_name=physnet

# Router to external
ovn-nbctl lrp-add lr-router lrp-public 00:00:00:00:02:02 203.0.113.1/24

ovn-nbctl lsp-add ls-public lsp-public
ovn-nbctl lsp-set-type lsp-public router
ovn-nbctl lsp-set-addresses lsp-public router
ovn-nbctl lsp-set-options lsp-public router-port=lrp-public

# Configure L3 Gateway
ovn-nbctl set logical_router lr-router \
    options:chassis=gw-node-1
ovn-nbctl set logical_router_port lrp-public \
    options:reside-on-chassis=gw-node-1

# SNAT && floating IP
ovn-nbctl -- --id=@nat create nat type=snat logical_ip=10.0.0.0/24 external_ip=203.0.113.1 -- add logical_router lr-router nat @nat

# DNAT
ovn-nbctl -- --id=@dnat create nat type=dnat_and_snat logical_ip=10.0.0.10 external_ip=203.0.113.100 -- add logical_router lr-router nat @dnat

# Default route on router
ovn-nbctl set logical_router lr-router \
    static_routes:0.0.0.0/0=203.0.113.1

# Configure br-ex on Host
ovs-vsctl add-br br-ex
ovs-vsctl add-port br-ex eth0 
ovs-vsctl set bridge br-ex \
    other_config:hwaddr=00:00:00:00:02:02

and configure IP/gateway on br-ex via /etc/netplan/ or systemd

```