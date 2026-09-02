# ns-bench.sh

**Netskope NewEdge PoP Latency Benchmarker**

Discovers every active Netskope NewEdge Point of Presence (PoP) in real time via the Netskope GSLB footprint API, probes each one using true ICMP ping, and reports the fastest PoP per city — grouped by region. Designed for macOS (Bash 3.2 compatible).

---

## What It Does

1. **Fetches the live NewEdge footprint** — Queries Netskope's GSLB API to get the current list of all PoP codes and their public IPs. This means results always reflect the actual deployed infrastructure, not a hardcoded list.

2. **Probes candidate PoPs per city** — For cities with multiple PoPs (e.g., New York has four: `US-NYC1–4`), each is pinged individually and only the fastest is shown. This eliminates noise and surfaces the PoP you'd actually be steered to.

3. **Measures true ICMP RTT** — Uses `ping -c 1` for raw round-trip latency, which is lower-overhead than an HTTP probe and gives a clean baseline for comparing PoP proximity.

4. **Color-coded latency output** — Results are color-graded at a glance:
   - 🟢 **Green** — under 30ms (optimal, likely your nearest PoP)
   - 🟡 **Yellow** — under 90ms (acceptable, regional hop)
   - 🔴 **Red** — 90ms+ (long distance or congested path)

---

## Why This Is Useful

When demonstrating or validating Netskope, a common question is: *"How much latency does the proxy actually add, and where is my traffic going?"* This script answers the first part — it maps every reachable PoP against your current network position so you can:

- Identify which PoPs are geographically closest to your machine
- Confirm whether your client is steering to the optimal PoP
- Spot unexpectedly high-latency PoPs that could indicate routing issues
- Build a credible, visual case for NewEdge's global density during a demo

Run this alongside `ns-tax.sh` (which measures the actual HTTP-layer proxy overhead) for a complete latency story.

---

## What Endpoint It Tests

- **GSLB Footprint API:** `https://gateway.gslb.goskope.com/api/v0.1/footprint/...`
- **Each PoP:** Its public egress IP, fetched dynamically from the footprint response

The GSLB endpoint was chosen because it's the authoritative source Netskope itself uses to route clients — it reflects exactly which PoPs are live at the time of the run, including any that have been added, removed, or changed. Hardcoding IPs would risk stale results.

---

## Prerequisites

- `bash` (3.2+ — macOS default is fine)
- `curl`
- `ping` with ICMP access (standard on macOS; may require `sudo` on some Linux distros depending on sysctl settings)
- Network access to the Netskope GSLB API (should be available on or off the Netskope client)

> **Note:** ICMP is blocked on some corporate networks. If you see a column of `TIMEOUT` results, verify ICMP is permitted outbound, or switch to a network without ICMP filtering.

---

## Usage

```bash
chmod +x ns-bench.sh
./ns-bench.sh
```

No arguments — the endpoint and PoP list are fully self-contained.

---

## Output

```
  Fetching Netskope NewEdge footprint...

  ▸ US Central
 City                  | Endpoint IP      | Best PoP  | Latency (RTT)
─────────────────────+─────────────────+──────────+────────────────
 Chicago, IL          | 163.116.128.45   | US-ORD1   |   11.4 ms
 St. Louis, MO        | 163.116.132.10   | US-STL1   |   18.2 ms
 Dallas, TX           | 163.116.136.88   | US-DFW4   |   24.7 ms
 Denver, CO           | 163.116.140.55   | US-DEN1   |   31.0 ms

  ▸ US East
 ...

  ▸ US West
 ...

  ▸ Canada & Mexico
 ...

  ▸ Global Sampler (Best PoP Per City)
 Dublin, Ireland      | 163.116.200.12   | IE-DUB1   |  112.3 ms
 ...

  Latency Legend: ■ <30ms (Optimal)  ■ <30ms (Good)  ■ >90ms (Long Distance)
```

### Reading the Results

| Column | What it means |
|--------|---------------|
| **City** | Geographic grouping — the metro area the PoP serves |
| **Endpoint IP** | The public IP of the fastest PoP in that city (as returned by the GSLB API) |
| **Best PoP** | The PoP code with the lowest RTT among all candidates for that city |
| **Latency (RTT)** | Raw ICMP round-trip time in milliseconds from your current machine |
| **TIMEOUT** | No ICMP response received — either the PoP is unreachable or ICMP is blocked |

---

## Covered Regions

| Region | Cities |
|--------|--------|
| US Central | Chicago, St. Louis, Dallas, Denver |
| US East | Boston, New York, Philadelphia, Ashburn, Atlanta, Miami |
| US West | Phoenix, Los Angeles, San Francisco, Seattle |
| Canada & Mexico | Montreal, Toronto, Calgary, Vancouver, Querétaro |
| Global Sampler | Dublin, London, Amsterdam, Paris, Frankfurt, Singapore, Tokyo, Sydney |

---

## Notes

- The script tests **one packet per PoP** (`-c 1`) to keep total runtime under ~30 seconds for the full run. For more stable averages, increase to `-c 3` and adjust the averaging logic in `probe_best_pop`.
- Cities with multiple PoP candidates (e.g., New York with `US-NYC1–4`) probe all candidates silently and surface only the winner — the full candidate list is visible in the script source.
- PoP codes follow Netskope's IATA-based naming convention (e.g., `US-ORD1` = Chicago O'Hare, `SG-SIN1` = Singapore).
