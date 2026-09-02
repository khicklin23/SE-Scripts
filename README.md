# Netskope Demo Scripts

A collection of Bash scripts for verifying and benchmarking Netskope NewEdge deployments. Built for macOS (Bash 3.2+), no dependencies beyond `curl` and `ping`.

---

## Scripts

| Script | What It Does |
|--------|-------------|
| [`ns-check.sh`](./scripts/ns-check) | Confirms steering is active and SSL inspection is in effect by checking the TLS certificate issuer. Also prints a full connection timing breakdown (DNS, TCP, TLS, TTFB). |
| [`ns-tax.sh`](./scripts/ns-tax) | Measures the per-request latency overhead added by Netskope. Run once with the client off, once with it on — prints the delta as the "proxy tax." |
| [`ns-bench.sh`](./scripts/ns-bench) | Fetches the live Netskope NewEdge PoP list via the GSLB API, pings candidate PoPs per city, and reports the fastest PoP and its RTT across US, Canada, and global regions. |
| [`ns-pop-raw.sh`](./scripts/ns-pop-raw) | Quick raw dump of the first 20 PoPs from the GSLB footprint API — PoP code, IP, and a single ICMP ping time. Useful for a fast sanity check of what's in the footprint. |

---

## Requirements

- macOS or Linux with Bash 3.2+
- `curl` with SSL support
- `ping` (ICMP) — some network environments block this; see individual script notes

---

## Quick Start

```bash
git clone <repo-url>
cd <repo>
chmod +x scripts/**/*.sh

# Verify steering & inspection
./scripts/ns-check/ns-check.sh

# Measure proxy tax (run twice — once client off, once on)
./scripts/ns-tax/ns-tax.sh

# Benchmark PoP latency by city
./scripts/ns-bench/ns-bench.sh

# Raw PoP list with RTT
./scripts/ns-pop-raw/ns-pop-raw.sh
```

---

## Which Script Should I Use?

- **"Is Netskope actually intercepting my traffic?"** → `ns-check.sh`
- **"How much latency is Netskope adding?"** → `ns-tax.sh`
- **"Which PoP am I closest to and what's the latency?"** → `ns-bench.sh`
- **"What does the raw NewEdge footprint look like?"** → `ns-pop-raw.sh`
