# Signals Haven Node: Wi-Fi HaLow Mesh Setup

> **Expert-Level Guide to Sub-Gigahertz High-Bandwidth Mesh Networks**
> 
> This document details the hardware assembly, software configuration, and integration of an off-grid "Haven Node" using Wi-Fi HaLow (IEEE 802.11ah). These nodes operate in the 900MHz ISM band and provide long-range, high-bandwidth peer-to-peer capabilities, enabling seamless connectivity for security cameras and off-grid communications like FaceTime and Signal without relying on internet infrastructure.

---

## Table of Contents

1. [Understanding Wi-Fi HaLow & Haven Nodes](#1-understanding-wi-fi-halow--haven-nodes)
2. [Hardware Selection & Assembly](#2-hardware-selection--assembly)
3. [Software Stack & Firmware](#3-software-stack--firmware)
4. [Mesh Configuration (batman-adv & 802.11s)](#4-mesh-configuration-batman-adv--80211s)
5. [Internet Uplink & Home Network Integration](#5-internet-uplink--home-network-integration)
6. [Security Camera Deployment](#6-security-camera-deployment)
7. [Peer-to-Peer App Configuration](#7-peer-to-peer-app-configuration)

---

## 1. Understanding Wi-Fi HaLow & Haven Nodes

A **Haven Node** utilizes **Wi-Fi HaLow (IEEE 802.11ah)**, a wireless networking protocol operating in the sub-gigahertz 900MHz band. Unlike traditional 2.4GHz or 5GHz Wi-Fi, HaLow significantly increases range (up to a few kilometers line-of-sight) and wall penetration capability at the cost of absolute throughput. 

### Key Capabilities:
- **Peer-to-Peer Applications**: Applications like Apple FaceTime, Signal, and Mumble can connect seamlessly peer-to-peer if they discover each other on the local network. They do *not* require an active internet connection to Apple or Meta servers for the video/audio streams once the handshake/discovery occurs locally.
- **Layer-2 Mesh**: Using `batman-adv` and `802.11s`, Haven Nodes create a transparent Layer-2 bridge. You can extend your home network into your yard and connect IP cameras as if they were hardwired to your main router.

---

## 2. Hardware Selection & Assembly

Building a Haven Node requires a single-board computer, a Wi-Fi HaLow radio, and appropriate antennas.

| Component | Recommended Options | Notes |
|-----------|--------------------|-------|
| **Compute Node** | Raspberry Pi 4 B (4GB+) | Pi 4 provides excellent driver support and USB 3.0 ports. Pi 5 can be used for higher SPI clock speeds (up to 50MHz) but requires careful power budgeting. |
| **HaLow Module** | Morse Micro WM6108 | Highly recommended due to maturity. Can use a mini-PCIe module with a HAT, or the MM8108-EKH05 USB dongle for prototyping. |
| **Adapter / HAT** | Seeed Studio WM6108 Pi HAT | Provides clean 40-pin GPIO routing, proper pull-ups for reset/wake/IRQ. |
| **Antenna** | 900MHz Dipole (2-3 dBi) | Good for general yard coverage. For long-range point-to-point (P2P), use a 13dBi Yagi (N-type). |
| **Power Supply** | 5V 3A+ USB-C | Use a robust PSU. Consider a PoE HAT if placing the node near an ethernet drop, which simplifies powering connected security cameras. |

### Assembly Steps
1. Attach the Morse Micro WM6108 HAT to the Raspberry Pi's GPIO pins.
2. Connect the 900MHz antenna to the SMA port on the module.
3. Ensure the Pi has adequate cooling, especially if placed in an outdoor enclosure.

---

## 3. Software Stack & Firmware

**OpenWrt (23.05+)** is the recommended base OS because it natively ships with advanced mesh routing packages (`wpad-mesh`, `batman-adv`).

### 3.1 Initial Setup
1. Flash the official OpenWrt image for your Raspberry Pi model onto an SD card.
2. Boot the Pi and connect via SSH (default IP usually `192.168.1.1`).
3. Install the required packages:
   ```bash
   opkg update
   opkg install kmod-morse morse-firmware hostapd-s1g wpa-supplicant-s1g kmod-batman-adv batctl
   ```

### 3.2 Morse Micro Driver Setup
If you are compiling from source or using a Debian-based Raspberry Pi OS:
1. Download the `mm-firmware` and `mm-driver` binaries from the Morse Micro repository.
2. Install the `.deb` packages.
3. Copy the Device-Tree Overlay (`wm6108-spi.dts`) to `/boot/overlays/` and add `dtoverlay=wm6108-spi` to `/boot/config.txt`.
4. Ensure the regulatory domain is set to your country (e.g., `country=US`) in the configuration to comply with transmit power limits (21 dBm max for 900MHz APs in the US).

Verify the driver loaded successfully:
```bash
dmesg | grep morse
```

---

## 4. Mesh Configuration (batman-adv & 802.11s)

To seamlessly bridge the network, we configure an 802.11s mesh interface and bind it to `batman-adv`.

### 4.1 Wireless Interface (802.11s)
Configure the radio in `/etc/config/wireless`:
```text
config wifi-device 'radio0'
    option type 'mac80211'
    option channel '28'           # 916 MHz
    option country 'US'
    option s1g_prim_chwidth '1'   # 8 MHz width
    option hwmode '11s'           # 802.11s Mesh Mode

config wifi-iface
    option device 'radio0'
    option network 'mesh0'
    option mode 'mesh'
    option mesh_id 'HavenMesh'
    option encryption 'sae'       # WPA3-SAE
    option key 'StrongMeshPassword'
```

### 4.2 Batman-adv Interface
Create the `bat0` interface in `/etc/config/network`:
```text
config interface 'bat0'
    option proto 'batadv'
    option mesh 'mesh0'
    option mtu '1536'
```

### 4.3 Bridging to LAN
Bridge the `bat0` interface to the physical ethernet port (`eth0`) so traffic flows transparently:
```text
config interface 'lan'
    option type 'bridge'
    list ports 'eth0' 'bat0'
    option proto 'static'
    option ipaddr '192.168.10.2'
    option netmask '255.255.255.0'
```
*Note: Ensure DHCP is disabled on the mesh nodes so your primary home router handles IP assignments.*

---

## 5. Internet Uplink & Home Network Integration

To extend your home network into your yard:

1. **The Gateway Node**: Build one Haven Node and connect its Ethernet port directly to your main home switch/router. This node acts as the bridge.
2. **The Yard Node**: Build a second Haven Node and place it in the yard (e.g., inside a weatherproof enclosure). 
3. **Transparent Bridging**: Because `batman-adv` operates at Layer 2, any device connected to the Yard Node's Ethernet or localized 2.4GHz AP will get an IP address from your main home router, granting it full internet access and local network discovery.

---

## 6. Security Camera Deployment

Deploying security cameras on this mesh is highly effective because Wi-Fi HaLow provides the necessary bandwidth for video streaming over long distances.

1. **Connect Cameras**: Plug your IP cameras into a PoE switch connected to the Yard Node, or directly into the Pi if using a PoE injection HAT.
2. **IP Addressing**: The cameras will receive IPs from your main home router. Consider assigning static IPs (e.g., `192.168.1.50`).
3. **QoS (Quality of Service)**: Since the HaLow link might have less bandwidth than gigabit ethernet, prioritize RTSP traffic (port 554) using OpenWrt's `sqm` or `tc` rules:
   ```bash
   tc qdisc add dev bat0 root handle 1: htb default 30
   tc class add dev bat0 parent 1: classid 1:10 htb rate 5Mbps ceil 10Mbps prio 1
   tc filter add dev bat0 protocol ip parent 1:0 prio 1 u32 match ip dport 554 0xffff flowid 1:10
   ```

---

## 7. Peer-to-Peer App Configuration

If the internet uplink fails, or if you intentionally build an off-grid network, several modern communication apps will continue to function seamlessly across the Haven Node mesh:

- **FaceTime**: Apple's FaceTime uses local discovery (mDNS/Bonjour) to find peers. If two iPhones are connected to the Haven mesh (e.g., via a localized 2.4GHz AP attached to the nodes), they will route high-quality video P2P across the 900MHz link. Ensure cellular data is disabled to force the local connection.
- **Signal**: The Signal app supports localized offline message delivery and calling if both devices are on the same subnet.
- **Mumble**: An open-source VoIP application. You can run a Mumble server directly on one of the Raspberry Pi nodes (e.g., `sudo apt install mumble-server`) and connect via the Mumla Android app or iOS client for high-quality, encrypted team comms with zero internet dependency.

> [!TIP]
> **Why this works**: Modern cloud dependencies have obscured the fact that the underlying protocols are still fundamentally peer-to-peer. The applications check for the destination IP, not just the internet connection. The Haven Node mesh ensures that discovery packets propagate successfully.
