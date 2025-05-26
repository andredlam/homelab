### Setup static IP address

```shell
# install this first
$ apt install openvswitch-switch-dpdk -y
$ apt install btop
$ apt install net-tools

# then
$ cd /etc/netplan
$ vi 50-cloud-init.yaml
network:
    ethernets:
        eno1:
            dhcp4: false
            dhcp6: false
            addresses: [10.0.0.99/24]
            routes:
              - to: default
                via:  10.0.0.1
            nameservers:
                addresses: [8.8.4.4, 8.8.8.8]
    version: 2

$ netplan generate
$ netplan apply

# MUST DISABLE SYSTEM FROM CHANGING INTERFACE
$ vi /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
network: {config: disabled}

```