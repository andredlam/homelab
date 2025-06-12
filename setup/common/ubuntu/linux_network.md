## Commands

```shell

$ ip route add 10.0.0.0/24 via 192.168.1.1
$ ip route add default via 192.168.1.1
```

#### Host as a router
```shell
$ cat /proc/sys/net/ipv4/ip_forward   # Check if IP forwarding is enabled. 0 means disabled, 1 means enabled.
$ echo 1 > /proc/sys/net/ipv4/ip_forward # Enable IP forwarding temporarily

# $ iptables -t nat -A POSTROUTING -o eno1 -j MASQUERADE # Enable NAT
$ echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf # Make it persistent
$ sysctl -p /etc/sysctl.conf # Apply changes

# Check routing table
$ ip route show
```

#### Nameserver
```shell
$ cat /etc/resolv.conf
# If you need to set a specific nameserver
namserver 192.168.1.100
nameserver 8.8.8.8
search lab.local datacenter.local
```

#### DNS Resolution
```shell
# Check if DNS resolution is working
$ cat /etc/nsswitch.conf    # then here

hosts:              files dns     << look at files first, then DNS
```

#### NS lookup
```shell
$ nsloopup www.google.com
$ dig www.google.com
```

#### Network namespaces
``` shell
ip netns add red
ip netns exec red ip link

ip link add veth-red type veth peer name veth-blue
ip link set veth-red netns red
ip link set veth-blue netns blue

ip -n red addr add 192.168.15.1 dev veth-red
ip -n blue addr add 192.168.15.2 dev veth-blue

ip -n red link set veth-red up
ip -n blue link set veth-blue up

ip netns exec red ping 192.168.15.2 dev veth-red

```


