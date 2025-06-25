#!/bin/bash

set -e

echo "Starting OVN Node Services..."

# Wait for OVN Central to be ready
echo "Waiting for OVN Central to be ready..."
while ! nc -z ${OVN_CENTRAL_IP} 6641; do
    echo "Waiting for OVN Northbound DB..."
    sleep 1
done

while ! nc -z ${OVN_CENTRAL_IP} 6642; do
    echo "Waiting for OVN Southbound DB..."
    sleep 1
done

echo "OVN Central is ready!"

# Start OVS
echo "Starting Open vSwitch..."
ovsdb-server /etc/openvswitch/conf.db \
    --remote=punix:/var/run/openvswitch/db.sock \
    --private-key=db:Open_vSwitch,SSL,private_key \
    --certificate=db:Open_vSwitch,SSL,certificate \
    --bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert \
    --log-file=/var/log/openvswitch/ovsdb-server.log \
    --pidfile=/var/run/openvswitch/ovsdb-server.pid \
    --detach

# Initialize OVS database if needed
if ! ovs-vsctl show > /dev/null 2>&1; then
    echo "Initializing OVS database..."
    ovs-vsctl --no-wait init
fi

# Start ovs-vswitchd
echo "Starting ovs-vswitchd..."
ovs-vswitchd \
    --log-file=/var/log/openvswitch/ovs-vswitchd.log \
    --pidfile=/var/run/openvswitch/ovs-vswitchd.pid \
    --detach

# Wait for OVS to be ready
sleep 2

# Configure OVS for OVN
echo "Configuring OVS for OVN..."
ovs-vsctl set open . external-ids:ovn-remote=tcp:${OVN_CENTRAL_IP}:6642
ovs-vsctl set open . external-ids:ovn-encap-type=geneve
ovs-vsctl set open . external-ids:ovn-encap-ip=${OVN_ENCAP_IP}

# Create integration bridge
ovs-vsctl --may-exist add-br br-int
ovs-vsctl set bridge br-int fail-mode=secure other-config:disable-in-band=true

# Start ovn-controller
echo "Starting ovn-controller..."
ovn-controller \
    --log-file=/var/log/ovn/ovn-controller.log \
    --pidfile=/var/run/ovn/ovn-controller.pid \
    --detach

echo "OVN Node services started successfully!"

# Check status
echo "Checking service status..."
if pgrep -f ovsdb-server > /dev/null; then
    echo "✓ OVS ovsdb-server is running"
else
    echo "✗ OVS ovsdb-server failed to start"
fi

if pgrep -f ovs-vswitchd > /dev/null; then
    echo "✓ ovs-vswitchd is running"
else
    echo "✗ ovs-vswitchd failed to start"
fi

if pgrep -f ovn-controller > /dev/null; then
    echo "✓ ovn-controller is running"
else
    echo "✗ ovn-controller failed to start"
fi

# Show OVS status
echo "OVS Configuration:"
ovs-vsctl show

# Keep container running and provide shell access
echo "OVN Node ready. Starting interactive shell..."
exec /bin/bash
