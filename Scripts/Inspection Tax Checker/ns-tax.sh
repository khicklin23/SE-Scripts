#!/bin/bash
# ==============================================================================
# Netskope Per-Request "Proxy Tax" Inspector (ns-tax.sh)
# macOS Compatible (Bash 3.2) | Steady-State TTFB Overhead Benchmarker
# ==============================================================================

# Hardcoded optimal destination: Cloudflare Global CDN Edge
TARGET_URL="https://www.cloudflare.com"
BASELINE_PROXIED="/tmp/ns_tax_baseline.txt.proxied"
BASELINE_DIRECT="/tmp/ns_tax_baseline.txt.direct"
REQUESTS=15

# ── ANSI Colors ────────────────────────────────────────────────────────────────
BOLD='\033[1m';   DIM='\033[2m';    NC='\033[0m'
CYAN='\033[0;36m'; BCYAN='\033[1;36m'
GREEN='\033[0;32m'; BGREEN='\033[1;32m'
YELLOW='\033[1;33m'; RED='\033[0;31m'
WHITE='\033[1;37m'

# ── Reset Flag ────────────────────────────────────────────────────────────────
if [ "$1" = "--reset" ]; then
    rm -f "$BASELINE_PROXIED" "$BASELINE_DIRECT"
    echo -e "\n${BGREEN}  Baselines cleared. Run script normally to start fresh.${NC}\n"
    exit 0
fi

echo -e "\n${BCYAN}======================================================${NC}"
echo -e "${BCYAN}      Netskope Per-Request \"Proxy Tax\" Inspector      ${NC}"
echo -e "${BCYAN}======================================================${NC}"
echo -e " Target   : ${YELLOW}${TARGET_URL}${NC}"
echo -e " Rationale: ${DIM}Static CDN edge endpoint selected for minimal origin${NC}"
echo -e "            ${DIM}server variance to isolate pure Netskope proxy overhead.${NC}"
echo -e " Samples  : ${DIM}${REQUESTS} measured requests + 5 warmup hits (excluded from avg)${NC}\n"

# 1. Steering & Inspection Check
echo -e "${WHITE}[+] Checking Steering & Inspection Status...${NC}"
CERT_ISSUER=$(curl -svI --connect-timeout 5 "$TARGET_URL" 2>&1 | grep -i "issuer:" | head -n 1)

if echo "$CERT_ISSUER" | grep -iq "netskope"; then
    IS_PROXIED=1
    STATUS_STR="${BGREEN}PROXIED (Netskope Steering Active)${NC}"
else
    IS_PROXIED=0
    STATUS_STR="${YELLOW}DIRECT (Netskope Bypassed / Off)${NC}"
fi

echo -e " Status   : $STATUS_STR"
echo -e " Issuer   : ${DIM}${CERT_ISSUER#*: }${NC}\n"

# 2. Multi-Hit Warmup Loop (5 requests + pause to establish cached policy state)
echo -e "${WHITE}[+] Warming up connection & priming inspection cache...${NC}"
w=0
while [ $w -lt 5 ]; do
    curl -s --keepalive-time 60 -o /dev/null --connect-timeout 5 "$TARGET_URL" 2>/dev/null
    w=$((w + 1))
done
sleep 1
echo -e " ${DIM}Done (steady-state established).${NC}\n"

# 3. Collect Samples (Req #1 shown but excluded from calculation)
echo -e "${WHITE}[+] Sending ${REQUESTS} measured requests (TTFB only)...${NC}\n"

EGRESS_IP=""
i=0
TIMES_FILE=$(mktemp /tmp/ns_times.XXXXXX)

while [ $i -lt $REQUESTS ]; do
    i=$((i + 1))

    RESULT=$(curl -s \
        --keepalive-time 60 \
        -w "%{time_starttransfer}|%{remote_ip}" \
        -o /dev/null \
        --connect-timeout 5 \
        "$TARGET_URL" 2>/dev/null)

    TIME_S=$(echo "$RESULT" | cut -d'|' -f1)
    IP=$(echo "$RESULT" | cut -d'|' -f2)

    IS_NUM=$(awk "BEGIN {print ($TIME_S == $TIME_S + 0) ? 1 : 0}" 2>/dev/null)
    if [ "$IS_NUM" != "1" ]; then
        printf " Req #%-2s : ${RED}ERR${NC}\n" "$i"
        continue
    fi

    TIME_MS=$(awk "BEGIN {printf \"%.2f\", $TIME_S * 1000}")
    [ -z "$EGRESS_IP" ] && EGRESS_IP="$IP"

    if [ $i -eq 1 ]; then
        # Print req #1 for visibility but exclude from average calculation
        printf " Req #%-2s ${DIM}(initial pipe — excluded)${NC} : %8s ms\n" "$i" "$TIME_MS"
    else
        printf " Req #%-2s ${DIM}(reused pipe)          ${NC} : %8s ms\n" "$i" "$TIME_MS"
        echo "$TIME_S" >> "$TIMES_FILE"
    fi
done

# 4. Trimmed Mean (drops single highest and lowest value from reqs #2-15)
AVG_MS=$(sort -n "$TIMES_FILE" | awk '
    { lines[NR] = $1 }
    END {
        if (NR <= 2) {
            print "0.00"
        } else {
            sum = 0; count = 0
            for (i = 2; i <= NR - 1; i++) {
                sum += lines[i]
                count++
            }
            printf "%.2f", (sum / count) * 1000
        }
    }
')

rm -f "$TIMES_FILE"

echo -e " ${DIM}──────────────────────────────────────────${NC}"
printf " ${BOLD}Trimmed Avg TTFB${NC} (reqs #2–15, excl. high/low) : ${GREEN}%s ms${NC}\n" "$AVG_MS"
printf " Egress Gateway IP                           : ${CYAN}%s${NC}\n" "$EGRESS_IP"

# 5. Tax Comparison
echo -e "\n${BCYAN}  ▸ Proxy Tax Comparison${NC}"
echo -e "${DIM} ──────────────────────────────────────────${NC}"

if [ $IS_PROXIED -eq 1 ]; then
    echo "PROXIED|${AVG_MS}" > "$BASELINE_PROXIED"
    if [ -f "$BASELINE_DIRECT" ]; then
        DIRECT_MS=$(cut -d'|' -f2 < "$BASELINE_DIRECT")
        TAX_MS=$(awk "BEGIN {printf \"%.2f\", $AVG_MS - $DIRECT_MS}")
        printf " Direct  (Netskope OFF) trimmed avg : %8s ms\n" "$DIRECT_MS"
        printf " Proxied (Netskope ON)  trimmed avg : %8s ms\n" "$AVG_MS"
        echo -e "${DIM} ──────────────────────────────────────────${NC}"
        if awk "BEGIN {exit !($TAX_MS <= 15)}"; then
            printf " ${BOLD}Netskope Per-Request Tax${NC} : ${BGREEN}  +%s ms (Negligible)${NC}\n" "$TAX_MS"
        else
            printf " ${BOLD}Netskope Per-Request Tax${NC} : ${YELLOW}  +%s ms${NC}\n" "$TAX_MS"
        fi
    else
        echo -e " ${DIM}Proxied baseline saved (${AVG_MS} ms).${NC}"
        echo -e " ${DIM}Pause the Netskope Client and re-run to complete the comparison.${NC}"
    fi
else
    echo "DIRECT|${AVG_MS}" > "$BASELINE_DIRECT"
    if [ -f "$BASELINE_PROXIED" ]; then
        PROXIED_MS=$(cut -d'|' -f2 < "$BASELINE_PROXIED")
        TAX_MS=$(awk "BEGIN {printf \"%.2f\", $PROXIED_MS - $AVG_MS}")
        printf " Direct  (Netskope OFF) trimmed avg : %8s ms\n" "$AVG_MS"
        printf " Proxied (Netskope ON)  trimmed avg : %8s ms\n" "$PROXIED_MS"
        echo -e "${DIM} ──────────────────────────────────────────${NC}"
        if awk "BEGIN {exit !($TAX_MS <= 15)}"; then
            printf " ${BOLD}Netskope Per-Request Tax${NC} : ${BGREEN}  +%s ms (Negligible)${NC}\n" "$TAX_MS"
        else
            printf " ${BOLD}Netskope Per-Request Tax${NC} : ${YELLOW}  +%s ms${NC}\n" "$TAX_MS"
        fi
    else
        echo -e " ${DIM}Direct baseline saved (${AVG_MS} ms).${NC}"
        echo -e " ${DIM}Re-enable the Netskope Client and re-run to complete the comparison.${NC}"
    fi
fi

echo -e "\n${BCYAN}======================================================${NC}\n"
