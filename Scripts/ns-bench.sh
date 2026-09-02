#!/bin/bash
# ==============================================================================
# Netskope NewEdge PoP Latency Benchmarker (Fastest PoP Per City)
# macOS Compatible (Bash 3.2) | True ICMP RTT Latency
# ==============================================================================

GSLB_URL="https://gateway.gslb.goskope.com/api/v0.1/footprint/zlury2HGBaFogNb3iQsK"

# ── ANSI Colors ────────────────────────────────────────────────────────────────
BOLD='\033[1m';   DIM='\033[2m';    NC='\033[0m'
CYAN='\033[0;36m'; BCYAN='\033[1;36m'
GREEN='\033[0;32m'; BGREEN='\033[1;32m'
YELLOW='\033[1;33m'; RED='\033[0;31m'
WHITE='\033[1;37m'

# ── Latency Color Helper ──────────────────────────────────────────────────────
color_ping() {
    local num=$1
    if awk "BEGIN {exit !($num < 30)}";   then printf "${BGREEN}%6.1f ms${NC}" "$num"
    elif awk "BEGIN {exit !($num < 80)}"; then printf "${YELLOW}%6.1f ms${NC}" "$num"
    else printf "${RED}%6.1f ms${NC}" "$num"
    fi
}

# ── Fetch GSLB footprint ──────────────────────────────────────────────────────
echo -e "\n${BCYAN}  Fetching Netskope NewEdge footprint...${NC}\n"
RESPONSE=$(curl -s --connect-timeout 5 "$GSLB_URL")
if [ -z "$RESPONSE" ]; then
    echo -e "${RED}  Error: Could not reach GSLB endpoint.${NC}"; exit 1
fi

TMPFILE=$(mktemp /tmp/ns_pops.XXXXXX)
POPS_RAW=$(echo "$RESPONSE" | sed -n 's/.*"pops":\[//p' | sed 's/]}}//')
echo "$POPS_RAW" | tr -d '\n' | sed 's/},{/}\n{/g' | while IFS= read -r pop; do
    code=$(echo "$pop" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
    ip=$(echo "$pop" | grep -o '"ip":"[^"]*"' | head -n1 | cut -d'"' -f4)
    [ -n "$code" ] && [ -n "$ip" ] && echo "${code}|${ip}" >> "$TMPFILE"
done

get_ip() {
    grep "^$1|" "$TMPFILE" | head -n1 | cut -d'|' -f2
}

# ── Probe city candidate PoPs & pick the fastest ──────────────────────────────
probe_best_pop() {
    local city_name=$1
    shift
    local candidates="$*"

    local best_code=""
    local best_ip=""
    local best_ping=999999

    for code in $candidates; do
        local ip
        ip=$(get_ip "$code")
        if [ -n "$ip" ]; then
            local p_time
            p_time=$(ping -c 1 -W 1000 "$ip" 2>/dev/null | grep -o 'time=[0-9.]*' | cut -d'=' -f2)
            if [ -n "$p_time" ]; then
                local is_faster
                is_faster=$(awk "BEGIN {print ($p_time < $best_ping) ? 1 : 0}")
                if [ "$is_faster" -eq 1 ]; then
                    best_ping=$p_time
                    best_code=$code
                    best_ip=$ip
                fi
            fi
        fi
    done

    if [ "$best_code" != "" ]; then
        local ping_colored
        ping_colored=$(color_ping "$best_ping")
        printf " %-20s ${DIM}|${NC} ${CYAN}%-15s${NC} ${DIM}|${NC} ${WHITE}%-8s${NC} ${DIM}|${NC} %-21s\n" \
            "$city_name" "$best_ip" "$best_code" "$ping_colored"
    else
        printf " %-20s ${DIM}|${NC} ${DIM}%-15s${NC} ${DIM}|${NC} ${DIM}%-8s${NC} ${DIM}|${NC} ${RED}%-14s${NC}\n" \
            "$city_name" "—" "—" "TIMEOUT"
    fi
}

# ── Print Section Header ──────────────────────────────────────────────────────
DIVIDER="${DIM}─────────────────────+─────────────────+──────────+────────────────${NC}"

print_section() {
    local label=$1
    echo -e "${BCYAN}  ▸ ${label}${NC}"
    printf "${BOLD}${WHITE}%-21s${NC} ${DIM}|${NC} ${BOLD}${WHITE}%-16s${NC} ${DIM}|${NC} ${BOLD}${WHITE}%-9s${NC} ${DIM}|${NC} ${BOLD}${WHITE}%-14s${NC}\n" \
        " City" "Endpoint IP" "Best PoP" "Latency (RTT)"
    echo -e "$DIVIDER"
}

# ── Execution ─────────────────────────────────────────────────────────────────

print_section "US Central"
probe_best_pop "Chicago, IL"        "US-ORD1 US-ORD2"
probe_best_pop "St. Louis, MO"      "US-STL1"
probe_best_pop "Dallas, TX"         "US-DFW1 US-DFW4"
probe_best_pop "Denver, CO"         "US-DEN1"

echo ""

print_section "US East"
probe_best_pop "Boston, MA"         "US-BOS1"
probe_best_pop "New York, NY"       "US-NYC1 US-NYC2 US-NYC3 US-NYC4"
probe_best_pop "Philadelphia, PA"   "US-PHL1"
probe_best_pop "Ashburn, VA"        "US-IAD2 US-IAD4"
probe_best_pop "Atlanta, GA"        "US-ATL1 US-ATL2"
probe_best_pop "Miami, FL"          "US-MIA1 US-MIA2"

echo ""
print_section "US West"
probe_best_pop "Phoenix, AZ"        "US-PHX1"
probe_best_pop "Los Angeles, CA"    "US-LAX1 US-LAX2"
probe_best_pop "San Francisco, CA"  "US-SFO1"
probe_best_pop "Seattle, WA"        "US-SEA2"

echo ""
print_section "Canada & Mexico"
probe_best_pop "Montreal, QC"       "CA-YMQ1 CA-YMQ3"
probe_best_pop "Toronto, ON"        "CA-YYZ1 CA-YYZ3"
probe_best_pop "Calgary, AB"        "CA-YYC1"
probe_best_pop "Vancouver, BC"      "CA-YVR1"
probe_best_pop "Queretaro, MX"      "MX-QRO1"

echo ""
print_section "Global Sampler (Best PoP Per City)"
probe_best_pop "Dublin, Ireland"    "IE-DUB1"
probe_best_pop "London, UK"         "UK-LON1 UK-LON2"
probe_best_pop "Amsterdam, NL"      "NL-AMS1"
probe_best_pop "Paris, France"      "FR-PAR1 FR-PAR2 FR-PAR3"
probe_best_pop "Frankfurt, Germany" "DE-FRA1"
probe_best_pop "Singapore"          "SG-SIN1"
probe_best_pop "Tokyo, Japan"       "JP-TYO1"
probe_best_pop "Sydney, Australia"  "AU-SYD1"

rm -f "$TMPFILE"

echo -e "\n  ${DIM}Latency Legend:${NC} ${BGREEN}■${NC}${DIM} <30ms (Optimal)  ${NC}${YELLOW}■${NC}${DIM} <90ms (Good)  ${NC}${RED}■${NC}${DIM} >90ms (Long Distance)${NC}\n"
