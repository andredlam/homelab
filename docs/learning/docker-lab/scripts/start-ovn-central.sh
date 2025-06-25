#!/bin/bash

set -e

echo "Starting OVN Central Services..."

# Initialize databases if they don't exist
if [ ! -f /var/lib/ovn/ovn-sb.db ]; then
    echo "Initializing OVN Southbound database..."
    ovsdb-tool create /var/lib/ovn/ovn-sb.db /usr/share/ovn/ovn-sb.ovsschema
fi

if [ ! -f /var/lib/ovn/ovn-nb.db ]; then
    echo "Initializing OVN Northbound database..."
    ovsdb-tool create /var/lib/ovn/ovn-nb.db /usr/share/ovn/ovn-nb.ovsschema
fi

# Start OVN Southbound database
echo "Starting OVN Southbound database..."
ovsdb-server /var/lib/ovn/ovn-sb.db \
    --remote=punix:/var/run/ovn/ovnsb_db.sock \
    --remote=ptcp:6642:0.0.0.0 \
    --private-key=db:Open_vSwitch,SSL,private_key \
    --certificate=db:Open_vSwitch,SSL,certificate \
    --bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert \
    --log-file=/var/log/ovn/ovsdb-server-sb.log \
    --pidfile=/var/run/ovn/ovsdb-server-sb.pid \
    --detach

# Start OVN Northbound database
echo "Starting OVN Northbound database..."
ovsdb-server /var/lib/ovn/ovn-nb.db \
    --remote=punix:/var/run/ovn/ovnnb_db.sock \
    --remote=ptcp:6641:0.0.0.0 \
    --private-key=db:Open_vSwitch,SSL,private_key \
    --certificate=db:Open_vSwitch,SSL,certificate \
    --bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert \
    --log-file=/var/log/ovn/ovsdb-server-nb.log \
    --pidfile=/var/run/ovn/ovsdb-server-nb.pid \
    --detach

# Wait for databases to be ready
sleep 2

# Start ovn-northd
echo "Starting ovn-northd..."
ovn-northd \
    --ovnnb-db=unix:/var/run/ovn/ovnnb_db.sock \
    --ovnsb-db=unix:/var/run/ovn/ovnsb_db.sock \
    --log-file=/var/log/ovn/ovn-northd.log \
    --pidfile=/var/run/ovn/ovn-northd.pid \
    --detach

echo "OVN Central services started successfully!"

# Check status
echo "Checking service status..."
if pgrep -f ovsdb-server > /dev/null; then
    echo "✓ OVSDB servers are running"
else
    echo "✗ OVSDB servers failed to start"
fi

if pgrep -f ovn-northd > /dev/null; then
    echo "✓ ovn-northd is running"
else
    echo "✗ ovn-northd failed to start"
fi

# Keep container running
echo "OVN Central ready. Keeping container alive..."
tail -f /var/log/ovn/*.log
