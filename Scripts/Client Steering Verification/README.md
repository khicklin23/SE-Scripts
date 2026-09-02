# Netskope Demo Scripts Repository

A collection of Bash scripts for demonstrating and validating Netskope endpoint steering, SSL inspection, and network behavior. Designed for sales demos, POC validation, and deployment verification.

---

## Repository Structure

```
netskope-scripts/
├── README.md                  # This file — overview & navigation
├── scripts/
│   ├── ns-check/
│   │   ├── ns-check.sh
│   │   └── README.md
│   ├── script-two/
│   │   ├── script-two.sh
│   │   └── README.md
│   ├── script-three/
│   │   ├── script-three.sh
│   │   └── README.md
│   └── script-four/
│       ├── script-four.sh
│       └── README.md
└── docs/                      # Optional: shared references, diagrams
```

---

## Scripts

| Script | Description | Link |
|--------|-------------|------|
| `ns-check.sh` | Verifies Netskope steering and SSL inspection status; includes full connection performance breakdown | [View →](./scripts/ns-check) |
| Script Two | _Description coming soon_ | [View →](./scripts/script-two) |
| Script Three | _Description coming soon_ | [View →](./scripts/script-three) |
| Script Four | _Description coming soon_ | [View →](./scripts/script-four) |

---

## Prerequisites

- `bash`
- `curl` (with SSL support — standard on macOS and most Linux distros)
- Netskope client installed and configured on the test endpoint

---

## Getting Started

Clone the repository and make scripts executable:

```bash
git clone https://github.com/your-org/netskope-scripts.git
cd netskope-scripts
chmod +x scripts/**/*.sh
```

---
---

# ns-check.sh

**Netskope Endpoint Inspection & Steering Verification Tool**

Verifies whether a host is actively being steered through the Netskope NewEdge proxy and whether SSL/TLS inspection (MITM) is in effect. Also provides a full connection performance breakdown so you can see exactly where time is being spent in the request lifecycle.

---

## What It Does

1. **SSL Inspection Check** — Fetches the TLS certificate from the target URL and checks whether the issuer is Netskope. A Netskope-issued cert confirms the client is being proxied and traffic is being inspected. A non-Netskope cert indicates the connection is going direct or bypassing the proxy.

2. **Connection Performance Breakdown** — Uses `curl`'s built-in timing metrics to report each phase of the request in milliseconds:
   - DNS Lookup
   - TCP Handshake
   - TLS Handshake
   - Time to First Byte (TTFB)
   - Total Round Trip

   The egress/gateway IP is also displayed — useful for confirming which Netskope PoP you're exiting through.

---

## Why This Is Useful

When demonstrating Netskope to a prospect or validating a client deployment, you need a quick, human-readable way to confirm:
- The Netskope client is running and steering traffic
- SSL inspection is active (not just steering)
- Which PoP is handling the traffic and what the latency profile looks like

This script gives you all three in a single run.

---

## Prerequisites

- `bash`
- `curl` (with SSL support — standard on macOS and most Linux distros)
- Netskope client installed and tunneling traffic (for inspection to show as active)

---

## Usage

```bash
# Test the default target (https://www.netskope.com)
./ns-check.sh

# Test a custom target
./ns-check.sh https://example.com
```

Make the script executable first if needed:
```bash
chmod +x ns-check.sh
```

---

## Output

```
====================================================
      Netskope Endpoint Inspection & Steering Check
====================================================
Testing target: https://www.netskope.com

[+] Inspecting SSL/TLS Certificate Chain...
  Status: ✔ SSL INSPECTION ACTIVE
  Issuer:  issuer: CN=Netskope Inc, O=Netskope Inc

[+] Connection Performance Breakdown...
  Egress Gateway IP: 163.116.128.45
  DNS Lookup          :   8.42 ms
  TCP Handshake       :  22.15 ms
  TLS Handshake       :  18.73 ms
  Time to First Byte  :  45.60 ms
  ------------------------------------
  Total Round Trip    :  94.90 ms
====================================================
```

### Reading the Results

| Field | What it means |
|-------|---------------|
| **SSL INSPECTION ACTIVE** | Netskope is intercepting and re-signing TLS — client is steered and inspecting |
| **DIRECT / BYPASSED** | Traffic is not going through Netskope, or this destination is on a bypass list |
| **Egress Gateway IP** | The IP the destination server sees — should be a Netskope PoP IP when proxied |
| **TLS Handshake** | Elevated TLS time compared to a direct connection indicates the MITM re-signing overhead |

---

## Notes

- The default target (`https://www.netskope.com`) is intentional — it's a reliable HTTPS endpoint that Netskope itself manages, making it a clean baseline for steering and inspection verification.
- If testing a custom target, choose a site that doesn't appear on your tenant's SSL bypass list, or results may show as direct even when the client is active.
- Run alongside other scripts in this repo to correlate inspection status with latency overhead.
