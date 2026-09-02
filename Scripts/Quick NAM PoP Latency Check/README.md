# ns-pop-raw.sh

**Netskope NewEdge Raw PoP Probe**

A lightweight, no-frills script that fetches the live Netskope NewEdge PoP list directly from the GSLB API and pings each entry, printing a raw latency table. No formatting, no sorting — just a fast snapshot of the first 20 PoPs and their ICMP round-trip times.

---

## What It Does

1. Hits the Netskope GSLB footprint API to retrieve the live list of NewEdge PoPs
2. Parses the response without any external dependencies (`jq`-free — pure `sed` and `grep`)
3. Sends a single ICMP ping to the primary IP of each PoP
4. Prints a simple `POP | IP | Latency` table for the first 20 entries

---

## When To Use This

This is a raw diagnostic script — use it when you want to:
- Quickly verify the GSLB API is reachable and returning data
- Get a fast, unfiltered latency snapshot without region grouping or formatting overhead
- Sanity-check PoP IPs before using them in other tools

For a polished, region-grouped output with color-coded latency and fastest-PoP-per-city logic, use [`ns-bench.sh`](../ns-bench) instead.

---

## Prerequisites

- `bash`
- `curl`
- `ping` (standard on macOS and Linux)
- No `jq` required

---

## Usage

```bash
chmod +x ns-pop-raw.sh
./ns-pop-raw.sh
```

No arguments. Output prints directly to terminal.

---

## Output

```
POP      | IP            | Time (ms)
=================================
US-ORD1  | 163.116.128.1 | 12.4 ms
US-NYC1  | 163.116.64.1  | 22.1 ms
US-LAX1  | 163.116.192.1 | 58.7 ms
...
```

- **POP** — Netskope PoP code as returned by the GSLB API
- **IP** — Primary IP for that PoP
- **Time (ms)** — Single-packet ICMP RTT; shows `N/A` if the PoP didn't respond

> Output is capped at 20 entries. The GSLB API returns the full global footprint — this script is intentionally limited for quick use.

---

## Notes

- Single-ping latency (`-c 1`) is not averaged — results can vary. Use `ns-bench.sh` for reliable multi-probe measurements.
- PoPs that don't respond to ICMP will show `N/A` — this doesn't necessarily mean the PoP is down, just that it may be blocking ping.
- The GSLB API key embedded in the URL is scoped to the Netskope demo tenant.
