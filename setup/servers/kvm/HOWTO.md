# KVM

## How-To

### Initial Setup on KVM

#### 1. Prepare network on KVM*
```shell

    # check interfaces to make sure eno1 and eno2 are available
    $ ip link
    1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
        link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    2: eno1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP mode DEFAULT group default qlen 1000
        link/ether 10:98:36:a8:c7:f2 brd ff:ff:ff:ff:ff:ff
        altname enp3s0f0
    3: eno2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP mode DEFAULT group default qlen 1000
        link/ether 10:98:36:a8:c7:f3 brd ff:ff:ff:ff:ff:ff
        altname enp3s0f1
    4: virbr0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN mode DEFAULT group default qlen 1000
        link/ether 52:54:00:0f:8b:5e brd ff:ff:ff:ff:ff:ff

    # Now remove default KVM network "virbr0"
    $ virsh net-destroy default
    $ virsh net-undefine default
    # if not work, use "ip link delete virbr0 type bridge

    # Configure network interfaces
    $ cd /etc/netplan
    $ vi 50-cloud-init.yaml
    network:
        ethernets:
            eno1:
                dhcp4: false
                dhcp6: false
                addresses: [10.0.0.<ip>/24]
                routes:
                    - to: default
                    via: 10.0.0.1
                nameservers:
                    addresses: [8.8.4.4, 8.8.8.8]
            eno2:
                dhcp4: false
                dhcp6: false
        vlans:
            vlan.100:
                id: 100
                link: eno2
            vlan.10:
                id: 10
                link: eno2
                dhcp4: false
                link-local: []
            vlan.20:
                id: 20
                link: eno2
                dhcp4: false
                link-local: []
            vlan.30:
                id: 30
                link: eno2
                link-local: []
            vlan.40:
                id: 40
                link: eno2
                link-local: []

        bridges:
            br0:
                interfaces: [eno2]
                addresses: [172.28.20.<ip>/24]
                mtu: 1500
                nameservers:
                    addresses: [8.8.8.8, 8.8.4.4]
                parameters:
                    stp: true
                    forward-delay: 4
            br-vlan.100:
                interfaces: [vlan.100]
                mtu: 1500
                parameters:
                    stp: false
                    forward-delay: 4
                link-local: []
                dhcp4: false
            br-vlan.10:
                interfaces: [vlan.10]
                mtu: 1500
                parameters:
                    stp: false
                    forward-delay: 4
                link-local: []
                dhcp4: false
            br-vlan.20:
                interfaces: [vlan.20]
                mtu: 1500
                parameters:
                    stp: false
                    forward-delay: 4
                link-local: []
                dhcp4: false
            br-vlan.30:
                interfaces: [vlan.30]
                mtu: 1500
                parameters:
                    stp: false
                    forward-delay: 4
                link-local: []
                dhcp4: false
            br-vlan.40:
                interfaces: [vlan.40]
                mtu: 1500
                parameters:
                    stp: false
                    forward-delay: 4
                link-local: []
                dhcp4: false

    version: 2
    
    $ netplan generate
    $ netplan apply

    $ brctl show
    bridge name	bridge id		    STP enabled	interfaces
    br-vlan.10		8000.eae4104b8727	no		vlan.10
    br-vlan.100		8000.1a7f0b3b5040	no		vlan.100
    br-vlan.20		8000.56220e97fc9d	no		vlan.20
    br-vlan.30		8000.aa7cacf0d2f8	no		vlan.30
    br-vlan.40		8000.725019f6f743	no		vlan.40
    br0		        8000.a6702c25f3e1	yes		eno2


    # check bridge
    $ brctl show br0

    # Add bridge network to KVM
    $ vi host-bridge.xml
    <network>
        <name>host-bridge</name>
        <forward mode="bridge"/>
        <bridge name="br0"/>
    </network>

    # Make br0 a default bridge
    $ virsh net-define host-bridge.xml
    $ virsh net-start host-bridge
    $ virsh net-autostart host-bridge

    $ virsh net-list --all
    Name          State    Autostart   Persistent
    ------------------------------------------------
    host-bridge   active   yes         yes
```

#### 2. Add ansible user to libvirt  group
```shell
    $ sudo usermod -aG libvirt ansible
```

#### 3. Run ansible to deploy VMs


#### 4. Check VMs after deployment

```shell

    # From KVM
    $ virsh list --all
    Id   Name     State
    ------------------------
    1    vm-120   running
    2    vm-121   running
    3    vm-122   running

    # Some commands
    $ virsh start <vm-name>
    $ virsh reboot <vm-name> (or <id#>)
    $ virsh suspend <vm-name> (or <id#>)
    $ virsh shutdown <vm-name> (or <id#>)

    # to completely remove VM
    $ virsh undefine <vm-name>
    $ virsh destroy <vm-name>

    $ virsh --help
```