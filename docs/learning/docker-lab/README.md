# OVN/OVS Docker Learning Environment

This directory contains Docker configurations for learning OVN and OVS in an isolated environment.

## Quick Start

```bash
# Build and start the learning environment
docker-compose up -d

# Access the main learning container
docker exec -it ovn-learning bash

# Run the first lab
cd /labs && ./lab1-ovs-basics.sh
```

## Environment Components

- **ovn-learning**: Main container with OVN/OVS pre-installed
- **ovn-central**: OVN central services (northbound/southbound databases)
- **ovn-node1/node2**: Additional nodes for multi-chassis labs

## Available Labs

1. **lab1-ovs-basics.sh**: Basic OVS operations
2. **lab2-vlan-isolation.sh**: VLAN-based network isolation
3. **lab3-ovn-setup.sh**: OVN logical networking
4. **lab4-multi-tenant.sh**: Multi-tenant scenarios
5. **lab5-performance.sh**: Performance testing and tuning

## Container Details

Each container includes:
- Ubuntu 20.04 base
- OVS 2.15+ and OVN 21.06+
- Network debugging tools (tcpdump, iperf3, etc.)
- Pre-configured lab scripts
- Documentation and reference materials

## Accessing Labs

```bash
# Interactive shell in learning container
docker exec -it ovn-learning bash

# Run specific lab
docker exec -it ovn-learning /labs/lab1-ovs-basics.sh

# View lab documentation
docker exec -it ovn-learning cat /docs/lab1-guide.md
```

## Cleanup

```bash
# Stop and remove containers
docker-compose down

# Remove volumes (resets lab state)
docker-compose down -v

# Remove custom networks
docker network prune
```
