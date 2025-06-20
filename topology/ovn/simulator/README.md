# OVN

## Containerized OVN/OVS

### Create a generic OVN/OVS container
https://github.com/ovn-org/ovn/blob/main/Documentation/intro/install/general.rst


##### 1. Install OVN/OVS from source to get the latest features

```shell
$ git clone https://github.com/ovn-org/ovn.git
$ apt install autoconf -y
$ apt install build-essential -y
$ apt install libtool -y
$ apt install libcap-ng-dev  # to run OVS daemons as a non-root
$ apt install linux-image-5.15.0-107-generic -y # needed by ovs-ctl

$ cd ovn
$ ./boot.sh                                 # generate configure script
$ git submodule update --init               # initialize submodules
$ cd ovs                                    # go to OVS submodule   
$ ./boot.sh                                 # generate configure script for OVS  

# OVN expects to find its database in /usr/local/etc/ovn
$ ./configure
# (./configure --prefix=/usr --sysconfdir=/etc --sharedstatedir=/var)
$ make -j 4
$ sudo make install
$ cd ..
$ ./configure
# (./configure --prefix=/usr --sysconfdir=/etc --sharedstatedir=/var)
$ make -j 4
$ sudo make install

# Need to start OVS before OVN
$ export PATH=$PATH:/usr/local/share/ovn/scripts
$ export PATH=$PATH:/usr/local/share/openvswitch/scripts

# start OVS first
$ ovs-ctl start # will start both ovs-switchd and ovsdb-server
# check status
$ ovs-ctl status
$ ps aux | grep -E "ovs-switchd|ovsdb-server"
$ ovs-appctl -t ovs-vswitchd version
$ ovs-appctl -t ovsdb-server version
# database for OVS: /usr/local/etc/openvswitch/conf.db

# Create database
$ mkdir -p /usr/local/etc/ovn
$ mkdir -p /usr/local/var/log/ovn
$ mkdir -p /usr/local/var/run/ovn

$ cd ~/ovn
$ ovsdb-tool create /usr/local/etc/ovn/ovnnb_db.db ovn-nb.ovsschema
$ ovsdb-tool create /usr/local/etc/ovn/ovnsb_db.db ovn-sb.ovsschema
$ ovsdb-tool create /usr/local/etc/ovn/ovn_ic_nb_db.db ovn-ic-nb.ovsschema
$ ovsdb-tool create /usr/local/etc/ovn/ovn_ic_sb_db.db ovn-ic-sb.ovsschema

```

##### 2. Build the OVN/OVS container

```shell
# Create a local folder for the OVN/OVS container
$ mkdir -p ~/ovn-builder
$ cd ~/ovn-builder
# Create a artifact directory
$ mkdir -p artifacts && cd artifacts
# Copy files from the OVN source
$ mkdir -p artifacts/usr/local/etc/ovn
$ cp -r /usr/local/etc/ovn/* artifacts/usr/local/etc/ovn/
$ mkdir -p artifacts/usr/local/var/log/ovn
$ mkdir -p artifacts/usr/local/var/run/ovn

cat <<'EOF' >> setup_artifacts.sh

# Copy files from the OVN source
mkdir -p artifacts/usr/local/etc/ovn
cp -r /usr/local/etc/ovn/* artifacts/usr/local/etc/ovn/
mkdir -p artifacts/usr/local/var/log/ovn
mkdir -p artifacts/usr/local/var/run/ovn

mkdir -p artifacts/usr/local/share/ovn/scripts
cp -r /usr/local/share/ovn/scripts/* artifacts/usr/local/share/ovn/scripts/

mkdir -p artifacts/usr/local/share/openvswitch/scripts
cp -r /usr/local/share/openvswitch/scripts/* artifacts/usr/local/share/openvswitch/scripts/

mkdir -p artifacts/usr/local/var/log/ovn
cp -r /usr/local/var/log/ovn/* artifacts/usr/local/var/log/ovn/
cp -r /usr/local/var/run/ovn/* artifacts/usr/local/var/run/ovn/

cp /usr/local/share/openvswitch/vswitch.ovsschema artifacts/usr/local/share/openvswitch/vswitch.ovsschema

mkdir -p artifacts/usr/local/bin/
cp -r /usr/local/bin/ovn** artifacts/usr/local/bin/
cp -r /usr/local/bin/ovs** artifacts/usr/local/bin/

COPY ../ovn/ovs/ovsdb/ovn* ovn/ovs/ovsdb/ovn*
COPY ../ovn/ovs/ovsdb/ovs* ovn/ovs/ovsdb/ovs*

mkdir -p artifacts/ovn/ovs/ovsdb/
# cp ../ovn/ovs/ovsdb/ovn* artifacts/ovn/ovs/ovsdb/
cp ../ovn/ovs/ovsdb/ovs* artifacts/ovn/ovs/ovsdb/

mkdir -p artifacts/ovn/ovs/vtep
mkdir -p artifacts/ovn/ovs/vswitchd
mkdir -p artifacts/ovn/ovs/utilities
cp ../ovn/ovs/vtep/vtep-ctl artifacts/ovn/ovs/vtep/vtep-ctl 
cp ../ovn/ovs/vswitchd/ovs-vswitchd artifacts/ovn/ovs/vswitchd/ovs-vswitchd
cp ../ovn/ovs/utilities/ovs-vsctl artifacts/ovn/ovs/utilities/ovs-vsctl
cp ../ovn/ovs/utilities/ovs-appctl artifacts/ovn/ovs/utilities/ovs-appctl
EOF

chmod +x setup_artifacts.sh
bash setup_artifacts.sh
```
