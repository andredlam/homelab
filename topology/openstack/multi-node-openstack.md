# OpenStack Multi-Node Deployment
This document provides a guide for deploying OpenStack in a multi-node environment.


## Environment Requirements
3 nodes with the following specifications:
- At least 64GB RAM
- At least 4 CPU cores
- At least 100GB disk space
- Ubuntu 24.04

Two network interfaces
- primary: for access to the OpenStack control plane
- secondary: for remote access to cloud VMs

##### Management Network
    Interface: eno1
    CIDR: 10.0.0.0/24
    Gateway: 10.0.0.1

##### Control plan network interface: 

    Interface: enp131s0f0
    CIDR: 172.16.1.0/24
    Gateway: 172.16.1.1
    Address range: 172.16.1.201-172.16.1.220

##### External network interface:

    Interface: enp131s0f1
    CIDR: 172.16.2.0/24
    Gateway: 172.16.2.1
    Address range: 172.16.2.2-172.16.2.254


## Installation
https://ubuntu.com/openstack/install

- ironman.lab.local         10.0.0.23   # role: control, compute, storage 
- batman.lab.local          10.0.0.22
- aquaman.lab.local         10.0.0.26



## Configuration
### Install on ironman 
(control,compute,storage node)

Setup hostname
```shell
    # node 1
    # Check system hostname
    $ hostname -f

    # Check libvirt hostname
    $ virsh hostname

    # update hostname
    $ vi /etc/hostname
    ironman.lab.local

    $ sudo hostnamectl set-hostname ironman.lab.local
    $ sudo systemctl restart libvirtd

    # Must have ssh keys generated
    $ ssh-keygen -t rsa

    # verify hostname
    $ virsh hostname
```

Configure Juju
```bash
    $ sudo apt install jq

    # Remove a Single Cloud
    $ juju clouds
    $ juju remove-cloud <cloud-name>
    $ juju kill-controller <cloud-name> -y
    $ juju remove-credential <cloud-name>


    # Remove existing controller if any
    $ juju kill-controller $(juju controllers --format=json | jq -r '.controllers | keys[]')

    $ juju add-cloud openstack-cloud
    => openstack

    $ juju add-credential openstack-cloud
    => enter "openstack"

    # Bootstrap with specific constraints
    $ juju bootstrap openstack-cloud \
        --constraints "mem=8G cores=2" \
        --debug

    # Add the machine
    $ juju add-machine ssh:ubuntu@10.0.0.23 \
        --constraints "mem=64G cores=4" \
        --debug
```
Check Machine Status
```shell
    # Check machine status
    $ juju status

    # View detailed machine info
    $ juju show-machine 0
```

```
    $ sudo snap install openstack
    $ sudo snap install juju --classic
    $ sudo echo "andre ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/andre

    # Deploy the OpenStack cloud using the cluster bootstrap command
    $ sudo usermod -a -G snap_daemon andre
    $ newgrp snap_daemon        # to apply group changes

    # Initialize Juju
    $ juju bootstrap localhost

    $ sudo snap connect openstack:ssh-keys
    $ sunbeam cluster bootstrap --role control,compute,storage


```


