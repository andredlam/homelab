# OpenStack

## Environment Requirements
- at least 64GB RAM
- at least 4 CPU cores
- at least 100GB disk space
- Ubuntu 24.04 or later
- KVM host with 2 interfaces
    - eno1 (management)
    - eno2 (data plane)


## Installation
https://docs.openstack.org/devstack/latest/

#### Servers
- ironman.lab.local
- batman.lab.local
- aquaman.lab.local
- superman.lab.local



#### Install on Ubuntu 24.04 using devstack
```shell
# Install OpenStack with devstack
# Devstack is a set of scripts and utilities to quickly deploy an OpenStack environment
$ sudo apt install git -y
$ sudo apt install openvswitch-switch-dpdk -y

# Optionally add "stack" user for running devstack
$ sudo useradd -s /bin/bash -d /opt/stack -m stack
$ sudo chmod +x /opt/stack
$ echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack
$ sudo -u stack -i

# Download and install devstack
$ git clone https://opendev.org/openstack/devstack
$ cd devstack

# Create local.conf configuration file
$ cat > local.conf << EOF
[[local|localrc]]
ADMIN_PASSWORD=secret
DATABASE_PASSWORD=\$ADMIN_PASSWORD
RABBIT_PASSWORD=\$ADMIN_PASSWORD
SERVICE_PASSWORD=\$ADMIN_PASSWORD
HOST_IP=<your nic2 ipaddr>  # e.g. 192.168.1.23

# External network
PUBLIC_INTERFACE=eno2
FLOATING_RANGE=192.168.1.0/24
PUBLIC_NETWORK_GATEWAY="192.168.1.1"
Q_FLOATING_ALLOCATION_POOL=start=192.168.1.200,end=192.168.1.254

# Enable services
ENABLED_SERVICES+=,key,n-api,n-crt,n-obj,n-cpu,n-cond,n-sch,n-cauth,placement-api,placement-client

GIT_BASE=https://opendev.org

enable_service rabbit
enable_plugin neutron $GIT_BASE/openstack/neutron

# Octavia supports using QoS policies on the VIP port:
enable_service q-qos
enable_service placement-api placement-client
# Octavia services
enable_plugin octavia $GIT_BASE/openstack/octavia master
enable_plugin octavia-dashboard $GIT_BASE/openstack/octavia-dashboard
enable_plugin ovn-octavia-provider $GIT_BASE/openstack/ovn-octavia-provider
enable_plugin octavia-tempest-plugin $GIT_BASE/openstack/octavia-tempest-plugin
enable_service octavia o-api o-cw o-hm o-hk o-da


# Logging configuration
LOGFILE=/opt/stack/logs/stack.sh.log
LOG_COLOR=False
EOF

# Make sure openvswitch is active
$ sudo systemctl status ovsdb-server.service
$ sudo systemctl start ovsdb-server.service

$ ./stack.sh
# The installation will take 20-30 minutes depending on your system and internet speed.

# To access the OpenStack dashboard, open a web browser and go to:
http://<your_host_ip>/dashboard
# Default credentials:
# Username: admin
# Password: secret

# Routing table on the host
$ ip route
default via 10.0.0.1 dev eno1 proto static
10.0.0.0/24 dev eno1 proto kernel scope link src 10.0.0.23
192.168.1.0/24 dev br-ex proto kernel scope link src 192.168.1.23
192.168.122.0/24 dev virbr0 proto kernel scope link src 192.168.122.1 linkdown
```

### Download Cloud image to use for OpenStack VM
```shell
# Download the latest Ubuntu cloud image
$ wget https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-amd64.img

$ wget https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img


# Verify the image
$ wget https://cloud-images.ubuntu.com/releases/jammy/release/SHA256SUMS
$ sha256sum -c SHA256SUMS 2>&1 | grep OK

```

### Create OpenStack VM
-  MUST create Security Group "ICMP" and "TCP" and assign to the VM in order to allow ping and ssh access


#### MUST ADD NAT RULES TO OPENSTACK HOST SO VM CAN ACCESS INTERNET
```shell
# assume 192.168.10.0/24 is the network for OpenStack VMs
$ iptables -t nat -A POSTROUTING -s 192.168.10.0/24 -j MASQUERADE
$ iptables -t nat -A PREROUTING -d 80 --to-destination 192.168.10.25 -j DNAT


# How linux does NAT
iptables -t nat -A PREROUTING -j DNAT --dport 8080 --to-destination 80
# How docker does NAT
iptables -t nat -A DOCKER -j DNAT --dport 8080 --to-destination 172.17.0.3:80

```
