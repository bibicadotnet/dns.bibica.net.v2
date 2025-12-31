# Public DNS Service (MosDNS-X & Caddy)

This documentation provides a technical overview and installation guide for a high-performance, encrypted DNS stack. It utilizes **MosDNS-X** for intelligent routing and **Caddy v2** for automatic SSL and reverse proxying.

## I. Technical Overview

### 1. Core Architecture and Query Flow

The system processes DNS queries through a structured pipeline to optimize speed and security:

* **Request Filtering:** Rejects `ANY` queries (RFC 8482), blocks IPv6 (AAAA) to prioritize IPv4 stability, and denies PTR (Reverse DNS) and Private TLD requests.
* **Sanitization:** Strips inbound Client Subnet (ECS) data and filters EDNS0 options for all upstream requests.
* **Performance:** Implements a 524,288-entry memory cache with **Lazy Cache** (TTL up to 86,400s) to serve cached responses immediately.
* **Domain Rewriting:** Applies local redirect and rewrite rules via `dns_redirect`.

### 2. Intelligent Upstream Routing

Queries are dynamically routed based on domain type to ensure optimal latency:

* **CDN Domains:** Routed to **Cloudflare Gateway** with ECS (EDNS Client Subnet) enabled for optimal edge server selection.
* **Google Domains:** Forwarded to **Google DNS** (`8.8.8.8`/`8.8.4.4`) with ECS support and minimal TTL adjustment.
* **Mullvad Domains:** Dedicated routing to `dns.mullvad.net`.
* **Standard Queries:** All other queries are processed by `upstream_cloudflare` (`1.1.1.1`/`1.0.0.1`).

### 3. Content Filtering

The system includes a built-in ad-blocking mechanism:

* **Blocklist & Allowlist:** Returns `NXDOMAIN` for domains in the blocklist, while the allowlist ensures essential services are not interrupted.

### 4. Protocol Support

The service supports modern encrypted DNS protocols out of the box:

* **DNS-over-HTTPS (DoH):** `https://<DOMAIN>/dns-query`
* **DNS-over-TLS (DoT):** `tls://<DOMAIN>`
* **DNS-over-HTTP/3 (DoH3):** `h3://<DOMAIN>/dns-query`
* **DNS-over-QUIC (DoQ):** `quic://<DOMAIN>`

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
