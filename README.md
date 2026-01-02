![6Rf8gynv](https://img.bibica.net/6Rf8gynv.png)
# Public DNS Service (MosDNS-X & Caddy)

This documentation provides a technical overview and installation guide for a high-performance, encrypted DNS stack. It utilizes **MosDNS-X** for intelligent routing and **Caddy v2** for automatic SSL and reverse proxying.

## I. Technical Overview

The system is designed using a Multi-Phase Pipeline model combined with Multi-Tier Redis Caching to optimize speed, privacy, and CDN resolution accuracy based on user location. This architecture ensures a balance between access speed, security, and geographic-specific CDN node optimization.

### PHASE 1: Traffic Filtering

Early rejection of junk queries to protect system resources:

* **Block Record Types:** `ANY` (DDoS prevention), `IPv6` (AAAA), and `PTR` (Reverse DNS).
* **Block Internal Domains:** Local TLDs such as `.lan, .local, .home`, etc.
* **Behavior:** Returns `REFUSED`, `NOTIMP`, or `NXDOMAIN`.

### PHASE 2: Normalization & Optimization

Packet sanitization before processing core logic:

* **Strip ECS:** Removes legacy Client Subnet info sent by client devices (if any).
* **Optimized MTU:** Limits packets to 1232 bytes to prevent fragmentation, optimized for local network infrastructure.
* **Internal Redirect:** Routes internal domains according to custom rules.

### PHASE 3: Security & Adblock

Validated against `blocklists.txt` and `allowlists.txt`.

* **Behavior:** If a domain is in `allowlists.txt`, it is bypassed even if present in the blocklist. If only present in `blocklists.txt`, the system returns `NXDOMAIN`.

### PHASE 4: Smart Routing

Classification and redirection to appropriate Upstreams:

* **Google Upstream:** For domains using Google DNS; appends ECS /24; utilizes dedicated cache.
* **Cloudflare Gateway Upstream:** For identified CDN domains; appends ECS /24; utilizes dedicated cache.
* **Mullvad Upstream:** For high-privacy domains; No ECS attached; utilizes dedicated cache.
* **Default Branch:** All remaining domains are forwarded to Cloudflare 1.1.1.1.

### PHASE 5: Recursive CDN Discovery

Applied to the Default Branch when a query resolves to a CDN CNAME:

* The system scans the CNAME records in the response.
* If a CDN infrastructure (e.g., Cloudfront, Akamai) is detected, the system appends ECS /24 and re-routes the query through Cloudflare Gateway to fetch the nearest CDN edge IP.

---

## Multi-Tier Redis Cache Structure

The system utilizes 5 isolated Redis databases to optimize routing logic:

| Database | Tag | Data Content | Technical Spec |
| --- | --- | --- | --- |
| Redis 0 | google_cache | Google DNS results | Includes ECS /24 (Location-aware) |
| Redis 1 | cdn_cache | CF Gateway results | Includes ECS /24 (Static CDN list) |
| Redis 2 | cname_cdn_cache | Recursive CDN results | Includes ECS /24 (Detected via Phase 5) |
| Redis 3 | mullvad_cache | Mullvad DNS results | Non-ECS (Absolute privacy) |
| Redis 4 | cloudflare_cache | Cloudflare DNS results | Non-ECS (General purpose) |

---

## Protocols & Management

### Supported Protocols

* Supports modern encrypted DNS protocols:

```
DNS-over-HTTPS (DoH): https://<DOMAIN>/dns-query
DNS-over-TLS (DoT): tls://<DOMAIN>
DNS-over-HTTP/3 (DoH3): h3://<DOMAIN>/dns-query
DNS-over-QUIC (DoQ): quic://<DOMAIN>
```

### System Management

* **Data Providers:** Configuration files for CDN, Google, Mullvad, and blocklists utilize auto_reload for real-time updates.
* **SSL Management:** Automated issuance and renewal of Let's Encrypt certificates via Caddy.
* **Logging:** Monitored at info level in log/mosdns.log along with _query_summary for activity auditing.

---

## II. Installation Guide

### 1. Prerequisites

* A Linux server (Debian 13 "Trixie" recommended) with root access.
* A domain name pointed to your server's IP address (A Record).
* A Cloudflare account with an **API Token** (Permissions: `Zone.DNS:Edit`).

### 2. Step 1: Initial VPS Setup

For a fresh VPS running Debian 13, run the following command to install Docker and apply basic system configurations without unnecessary tweaks:

```bash
apt install -y curl sudo && curl -fsSL go.bibica.net/vps | sudo bash

```

### 3. Step 2: Install Public DNS Service

Run the automated installation script:

```bash
wget -qO /home/setup-dns-bibica-net-v2.sh https://go.bibica.net/setup-dns-bibica-net-v2 && sudo bash /home/setup-dns-bibica-net-v2.sh

```

### 4. Setup Steps

1. **Domain Input:** Enter the domain you wish to use (e.g., `dns.example.com`).
2. **API Token:** Paste your Cloudflare API Token for SSL verification.
3. **Automatic Deployment:** The script will install the source files, configure the stack, request SSL certificates, and set up a daily cron job (2:00 AM) for ad-block list updates.

---

## III. Firewall Customization (Geo-IP)

To protect the server from global DNS attacks, use the included Geo-IP firewall script.

### 1. Editing Configuration

Open the firewall script:
`nano /home/setup-geo-firewall.sh`

By default, the script only allows IP addresses from **Vietnam (VN)** to access the VPS:

```bash
ALLOW_COUNTRIES=("VN")
ALLOW_TCP_PORTS=("22" "443" "853")
ALLOW_UDP_PORTS=("443" "853")

```

### 2. Customization Guide

* **Change Country:** Change `"VN"` to your desired ISO country code (e.g., `"US"` for USA, `"SG"` for Singapore). To allow multiple countries: `ALLOW_COUNTRIES=("VN" "SG" "US")`.
* **Add Ports:** Add any additional ports to `ALLOW_TCP_PORTS` or `ALLOW_UDP_PORTS`.
* **Defaults:** All other values can remain as default.

### 3. Apply Changes

After adjusting the configuration, run the script to apply the firewall rules:

```bash
sudo /home/setup-geo-firewall.sh

```
