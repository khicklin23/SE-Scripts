# ns-tax.sh

**Netskope Per-Request "Proxy Tax" Inspector**

Measures the real-world TTFB latency overhead added by the Netskope NewEdge proxy on a per-request basis. Run it twice — once with the Netskope client off, once with it on — and the script automatically calculates the delta: the exact millisecond cost of Netskope inspection on each request.

---

## What Endpoint It Tests

| Field | Value |
|-------|-------|
| **Target URL** | `https://www.cloudflare.com` |
| **What it is** | Cloudflare's global CDN edge |
| **Why it was chosen** | Cloudflare serves responses directly from the nearest edge node with near-zero origin variance. Because the response time is extremely stable request-to-request, it isolates the Netskope proxy as the only meaningful variable. A high-variance origin (e.g., a dynamic app server) would muddy the comparison and make the tax measurement unreliable. |

---

## How It Works

The script is designed to be run **twice in sequence** — the order doesn't matter, but both states are required for a comparison:

1. **Run 1 — Client OFF (Direct):** Captures a trimmed average TTFB baseline with Netskope disabled. Saves result to `/tmp/ns_tax_baseline.txt.direct`.
2. **Run 2 — Client ON (Proxied):** Captures a trimmed average TTFB with Netskope steering and inspecting traffic. Saves result to `/tmp/ns_tax_baseline.txt.proxied`.

Once both baselines exist, the script displays the full comparison and computes the proxy tax automatically.

### Measurement Methodology

- **5 warmup requests** are sent first and discarded — these prime the Netskope policy cache and establish a persistent TCP connection, so you're not measuring cold-start overhead.
- **15 measured requests** are sent using keep-alive (reused pipe). Request #1 is printed for visibility but excluded from the average — it still carries initial pipe setup cost.
- **Requests #2–15** are used for the average. The single highest and lowest values are dropped (trimmed mean) to reduce noise from occasional outliers.
- **TTFB only** (`time_starttransfer`) is measured — not total transfer time — to focus purely on proxy processing latency rather than response body size.

---

## Prerequisites

- `bash`
- `curl` (standard on macOS and most Linux distros)
- Ability to toggle the Netskope client on/off between runs

---

## Usage

### Step 1 — Run with Netskope client OFF
```bash
./ns-tax.sh
```
You'll see the direct baseline saved and a prompt to re-enable the client.

### Step 2 — Enable the Netskope client, then run again
```bash
./ns-tax.sh
```
The script detects the saved direct baseline, runs the proxied measurement, and prints the full comparison.

### Reset baselines and start fresh
```bash
./ns-tax.sh --reset
```
Clears both saved baselines from `/tmp`. Use this between demos or when switching networks.

Make the script executable first if needed:
```bash
chmod +x ns-tax.sh
```

---

## Output

### After Run 1 (Direct baseline only)
```
  ▸ Proxy Tax Comparison
 ──────────────────────────────────────────
  Direct baseline saved (18.43 ms).
  Re-enable the Netskope Client and re-run to complete the comparison.
```

### After Run 2 (Full comparison)
```
======================================================
      Netskope Per-Request "Proxy Tax" Inspector
======================================================
 Target   : https://www.cloudflare.com
 Rationale: Static CDN edge endpoint selected for minimal origin
             server variance to isolate pure Netskope proxy overhead.
 Samples  : 15 measured requests + 5 warmup hits (excluded from avg)

[+] Checking Steering & Inspection Status...
 Status   : PROXIED (Netskope Steering Active)
 Issuer   : issuer: CN=Netskope Inc, O=Netskope Inc

[+] Warming up connection & priming inspection cache...
 Done (steady-state established).

[+] Sending 15 measured requests (TTFB only)...

 Req #1  (initial pipe — excluded)  :    31.44 ms
 Req #2  (reused pipe)              :    22.18 ms
 Req #3  (reused pipe)              :    21.97 ms
 ...
 Req #15 (reused pipe)              :    22.54 ms
 ──────────────────────────────────────────
 Trimmed Avg TTFB (reqs #2–15, excl. high/low) : 22.31 ms
 Egress Gateway IP                              : 163.116.128.45

  ▸ Proxy Tax Comparison
 ──────────────────────────────────────────
 Direct  (Netskope OFF) trimmed avg :    18.43 ms
 Proxied (Netskope ON)  trimmed avg :    22.31 ms
 ──────────────────────────────────────────
 Netskope Per-Request Tax           :   +3.88 ms (Negligible)
======================================================
```

### Reading the Results

| Output | What it means |
|--------|---------------|
| **PROXIED (Netskope Steering Active)** | TLS cert issuer is Netskope — traffic is being intercepted and inspected |
| **DIRECT (Netskope Bypassed / Off)** | No Netskope cert detected — connection is going straight to origin |
| **Egress Gateway IP** | The IP the destination sees — should be a Netskope PoP IP when proxied |
| **Trimmed Avg TTFB** | The steady-state per-request latency after warmup, with outliers removed |
| **Proxy Tax ≤ 15ms** | Displayed in green as **Negligible** — within Netskope's expected overhead range |
| **Proxy Tax > 15ms** | Displayed in yellow — worth investigating PoP proximity with `ns-bench.sh` |

---

## Notes

- Baselines persist in `/tmp` across runs until you `--reset` or reboot. This lets you run the direct and proxied measurements minutes apart without losing context.
- If you switch networks (e.g., office to home, or VPN on/off) between runs, reset the baselines — the network path changes will make the comparison meaningless.
- For the most accurate tax reading, run both measurements on the same network, back to back, with no other significant network activity.
- Pair with `ns-bench.sh` to identify your closest PoP if the proxied tax is higher than expected — a far PoP is the most common cause of elevated overhead.
