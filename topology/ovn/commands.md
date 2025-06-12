
### Installation
```shell
sudo apt update
sudo apt install -y openvswitch-switch ovn-common ovn-central ovn-host mininet python3-pip

# Start OVN Northbound and Southbound DBs
sudo ovn-nbctl set-connection ptcp:6641
sudo ovn-sbctl set-connection ptcp:6642
```


### OVN Commands

#### Northbound commands
```shell

ovn-nbctl show                                  # Show OVN NB database contents
ovn-nbctl ls-add sw0                            # Add a new logical switch
ovn-nbctl lsp-add sw0 port1                     # Add a logical port to the switch
ovn-nbctl lsp-set-addresses port1 "<mac>"       # set MAC
ovn-nbctl lsp-set-addresses port1 "<mac> <ip>"  # set MAC and IP
sudo ovn-nbctl lsp-set-addresses lsp-h1 "02:00:00:00:00:01 10.0.0.1"

ovn-nbctl lsp-set-type port1 router         # Set port type to router

```

#### Southbound commands
```shell
ovn-sbctl show                                  # Show OVN SB database contents
ovn-sbctl list chassis                          # List all chassis
_uuid               : e79a3960-2397-4352-932a-1635eaef4902
encaps              : [16348d62-df2f-4c8e-9942-c53f16f9ece3]
external_ids        : {}
hostname            : node3
name                : "8abca7ba-2962-4cae-b24f-2013ef53883f"
nb_cfg              : 0
other_config        : {ct-commit-nat-v2="true", ct-commit-to-zone="true", ct-no-masked-label="true", datapath-type=system, fdb-timestamp="true", iface-types="afxdp,afxdp-nonpmd,bareudp,erspan,geneve,gre,gtpu,internal,ip6erspan,ip6gre,lisp,patch,srv6,stt,system,tap,vxlan", is-interconn="false", ls-dpg-column="true", mac-binding-timestamp="true", ovn-bridge-mappings="", ovn-chassis-mac-mappings="", ovn-cms-options="", ovn-ct-lb-related="true", ovn-enable-lflow-cache="true", ovn-limit-lflow-cache="", ovn-memlimit-lflow-cache-kb="", ovn-monitor-all="false", ovn-trim-limit-lflow-cache="", ovn-trim-timeout-ms="", ovn-trim-wmark-perc-lflow-cache="", port-up-notif="true"}
transport_zones     : []
vtep_logical_switches: []

_uuid               : b31de63b-c749-4e14-844b-625335bde193
encaps              : [093e243d-d371-4499-9c73-280e61d1779a]
external_ids        : {}
hostname            : node1
== More Information ==

You can find out more about Ubuntu on our website, IRC channel and wiki.
nb_cfg              : 0
other_config        : {ct-commit-nat-v2="true", ct-commit-to-zone="true", ct-no-masked-label="true", datapath-type=system, fdb-timestamp="true", iface-types="afxdp,afxdp-nonpmd,bareudp,erspan,geneve,gre,gtpu,internal,ip6erspan,ip6gre,lisp,patch,srv6,stt,system,tap,vxlan", is-interconn="false", ls-dpg-column="true", mac-binding-timestamp="true", ovn-bridge-mappings="", ovn-chassis-mac-mappings="", ovn-cms-options="", ovn-ct-lb-related="true", ovn-enable-lflow-cache="true", ovn-limit-lflow-cache="", ovn-memlimit-lflow-cache-kb="", ovn-monitor-all="false", ovn-trim-limit-lflow-cache="", ovn-trim-timeout-ms="", ovn-trim-wmark-perc-lflow-cache="", port-up-notif="true"}
transport_zones     : []
vtep_logical_switches: []


ovn-sbctl chassis-add <chassis-name> <ip>   # Add a new chassis
ovn-sbctl chassis-list                      # List all chassis
ovn-sbctl chassis-del <chassis-name>        # Delete a chassis
ovn-sbctl set-connection ptcp:<port>        # Set connection port for SBDB
ovn-sbctl set-connection tcp:<ip>:<port>    # Set connection to a remote OVN SBDB
ovn-sbctl set-connection ptcp:6642          # Set local SBDB connection

```


#### OVS, OVN-Controller Commands
```shell
$ ovs-vsctl show                                  # Show OVS configuration
7fdffa25-1043-402b-a4ed-2ec64ec8a4b9
    Bridge br-int
        fail_mode: secure
        datapath_type: system
        Port br-int
            Interface br-int
                type: internal
        Port ovn-8abca7-0
            Interface ovn-8abca7-0
                type: geneve
                options: {csum="true", key=flow, remote_ip="10.0.0.191"}
    ovs_version: "3.3.0"

$ ovs-vsctl list-ports br-int
ovn-8abca7-0

$ $ovs-vsctl list-ports br-ex
ovs-vsctl: no bridge named br-ex
```

### how to use OVN to setup  L3 gateway, floating IPs, NAT
```
VM (10.0.0.10) ───┬── Logical Switch (private)
                 │
         Logical Router
                 │
         Provider Network (public)
                 │
              Internet
```

Assume:

- Private subnet: 10.0.0.0/24
- Public (provider) subnet: 203.0.113.0/24
- Floating IP: 203.0.113.100
- VM internal IP: 10.0.0.10
- External bridge: br-ex

```shell
# Create logical switch and router
ovn-nbctl ls-add ls-private
ovn-nbctl lr-add lr-router

# --
# Connect Logical Switch to Router

# Router Port
ovn-nbctl lrp-add lr-router lrp-private 00:00:00:00:01:01 10.0.0.1/24

# Switch Port
ovn-nbctl lsp-add ls-private lsp-private
ovn-nbctl lsp-set-type lsp-private router
ovn-nbctl lsp-set-addresses lsp-private router
ovn-nbctl lsp-set-options lsp-private router-port=lrp-private
ovn-nbctl lsp-set-port-security lsp-private 00:00:00:00:01:01

# --
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




```