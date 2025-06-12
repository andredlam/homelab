# SR-IOV

## SR-IOV Overview

### Compare with OVN
SR-IOV (Single Root I/O Virtualization) is a technology that allows a single physical network interface card (NIC) to present itself as multiple virtual NICs (vNICs) to the operating system. This enables better resource utilization and performance for virtualized environments.
Unlike OVN, which abstracts networking at a higher level, SR-IOV operates at the hardware level, allowing direct access to the physical NICs from virtual machines (VMs) or containers. This can lead to lower latency and higher throughput for network-intensive applications.

### 🧩 How SR-IOV Works in Servers
- **PF (Physical Function):**
This is the actual hardware device (e.g., the physical NIC on the PCIe bus).

- **VF (Virtual Functions):**
Lightweight virtual PCIe functions carved from the PF. Each VF has its own MAC address, DMA queue, and appears as a separate PCI device to the OS.

- **Hypervisor Pass-Through:**
VFs are assigned directly to VMs (like PCI passthrough), bypassing the hypervisor's virtual switch (e.g., OVS or vSwitch). This allows:
    - Lower latency
    - Higher throughput
    - Reduced CPU overhead

#### 🧠 So, How Is SR-IOV Related to OVS?
##### 1. They Both Serve VM Networking — in Different Ways
    - OVS: Acts as a virtual switch — connecting VMs to logical networks, applying policies, QoS, ACLs, tunnels, etc.
    - SR-IOV: Bypasses software switching entirely — gives VMs direct access to a virtual function (VF) on the NIC.

➡️ When you use SR-IOV, traffic usually bypasses OVS — which means no software-based switching or OVN logic is applied on the data path.

##### 2. SR-IOV in OpenStack + OVS
In OpenStack (and Kubernetes with Multus), you can combine SR-IOV and OVS:
    - **Use SR-IOV for high-speed interfaces (e.g., for NFV apps or DPDK workloads)**
    - **Use OVS (with OVN) for control-plane, overlay networks, floating IPs, etc.**

For example:
- eth0 → used by OVS/OVN (br-int, br-ex)
- eth1 with SR-IOV VFs → bound directly to VMs for high-throughput data

##### 3. OVS Can Co-Exist with SR-IOV
While SR-IOV VFs aren't directly managed by OVS, you can:
- Use **representor ports** (if supported by NIC) and connect them to br-int for monitoring/control
- Or just combine SR-IOV + OVS ports on a VM (e.g., dual NIC setup: one for control, one for fast path)

###### 4. OVS-DPDK vs SR-IOV
Both aim to accelerate packet processing:
- OVS-DPDK: Still uses OVS but offloads switching into userspace DPDK
- SR-IOV: Gives NIC's VF directly to VM, skipping the host stack entirely

|Use Case|Recommended|
|---|---|
|Full SDN control|OVS / OVN|
|Max throughput / lowest latency|SR-IOV|
|Hybrid (control + performance)|OVS + SR-IOV|

### ✅ Summary
- SR-IOV and OVS can coexist, but they serve different purposes:
    - SR-IOV: Raw speed, less flexibility
    - OVS: SDN control, overlays, security groups

- In OVN/OVS networks, SR-IOV traffic bypasses logical routers/switches unless integrated via representor ports.

- **Use SR-IOV for fast-path workloads, and OVS/OVN for overlay, multi-tenant traffic, or where control/visibility is needed.**


### 🧩 What Are Representor Ports?
When SR-IOV is enabled on modern NICs (e.g., Mellanox, Intel XL710/XXV710, or ConnectX):
- Each VF (Virtual Function) exposed by the NIC has an associated representor port on the host.
- These representor ports appear as regular interfaces in Linux and allow:
    - Policy control
    - Flow monitoring
    - Bridge connection (e.g., to br-int)

- They’re mirrors of VF traffic that allow you to manipulate it using tools like OVS.