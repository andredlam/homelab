# KVM

## How-To

### Initial Setup on KVM

#### 1. Prepare network on KVM*

```shell
network:
    ethernets:
      eno1:
        dhcp4: false
        dhcp6: false
        addresses: [10.0.0.22/24]
        routes:
          - to: default
            via: 10.0.0.1
        nameservers:
          addresses: [8.8.8.8, 8.8.4.4]
      eno2:
        dhcp4: false
        dhcp6: false
        addresses: [172.16.0.22/24]

    version: 2

```