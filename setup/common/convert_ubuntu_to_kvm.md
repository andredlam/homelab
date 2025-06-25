# KVM Setup

## How-To

#### 1. Requirements

- Ubuntu 22.04
- Server with 2 interfaces
    - eno1 (management) 
    - eno2 (data plane)


#### 2. Setup KVM

```shell
    # Reference: https://ostechnix.com/ubuntu-install-kvm/

    # Install ubuntu 22.04 on bare-metal
    
    # check for virtualization support
    $ egrep -c '(vmx|svm)' /proc/cpuinfo

    # check KVM enabled
    $ sudo apt install -y cpu-checker
    $ kvm-ok
      INFO: /dev/kvm exists
      KVM acceleration can be used

    # Install KVM on Ubuntu 22.04
    $ apt install openvswitch-switch-dpdk -y
    $ apt install -y qemu-kvm virt-manager libvirt-daemon-system virtinst libvirt-clients bridge-utils

    # Enable virtualization daemon
    $ sudo systemctl enable --now libvirtd
    $ sudo systemctl start libvirtd

    # To confirm it's running
    $ sudo systemctl status libvirtd

    # Allow current user to manage kvm and libvirt
    $ sudo usermod -aG kvm $USER
    $ sudo usermod -aG libvirt $USER

    # Add ansible user
    $ sudo adduser ansible
    # Allow ansible to do sudo
    $ sudo usermod -aG sudo ansible
    $ passwd ansible # Set password for ansible user

    # disable netfilter for performance and security reasons
    $ vi /etc/sysctl.d/bridge.conf
    net.bridge.bridge-nf-call-ip6tables=0
    net.bridge.bridge-nf-call-iptables=0
    net.bridge.bridge-nf-call-arptables=0

    $ vi /etc/udev/rules.d/99-bridge.rules
    ACTION=="add", SUBSYSTEM=="module", KERNEL=="br_netfilter", RUN+="/sbin/sysctl -p /etc/sysctl.d/bridge.conf"

    $ reboot
```


3. Access VMs on KVM

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
    $ virsh console <vm-name>                   # Connect to console
    $ virsh reboot <vm-name> (or <id#>)
    $ virsh suspend <vm-name> (or <id#>)
    $ virsh shutdown <vm-name> (or <id#>)

    To exit console "Ctrl + ]"

    # to completely remove VM
    $ virsh undefine <vm-name>
    $ virsh destroy <vm-name>

    $ virsh --help

```