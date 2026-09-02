#!/bin/bash
# ==============================================================================
# Netskope Inspection & Steering Verification Tool
# Demonstration Script for Endpoint Steering & MITM Inspection Status
# ==============================================================================

# ANSI Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TARGET_URL="${1:-https://www.netskope.com}"

echo -e "${CYAN}====================================================${NC}"
echo -e "${CYAN}      Netskope Endpoint Inspection & Steering Check  ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo -e "Testing target: ${YELLOW}${TARGET_URL}${NC}\n"

# 1. SSL/TLS Certificate Issuer Check (MITM Detection)
echo -e "${BLUE}[+] Inspecting SSL/TLS Certificate Chain...${NC}"
CERT_ISSUER=$(curl -svI --connect-timeout 5 "$TARGET_URL" 2>&1 | grep -i "issuer:" | head -n 1)

if echo "$CERT_ISSUER" | grep -iq "netskope"; then
    echo -e "  Status: ${GREEN}✔ SSL INSPECTION ACTIVE${NC}"
    echo -e "  Issuer: ${GREEN}${CERT_ISSUER#*: }${NC}"
else
    echo -e "  Status: ${RED}✘ DIRECT / BYPASSED (No Netskope Cert Detected)${NC}"
    echo -e "  Issuer: ${YELLOW}${CERT_ISSUER#*: }${NC}"
fi

echo ""

# 2. Network Latency & Handshake Performance Breakdown
echo -e "${BLUE}[+] Connection Performance Breakdown...${NC}"
PERF_DATA=$(curl -s -w "%{time_namelookup}|%{time_connect}|%{time_appconnect}|%{time_starttransfer}|%{time_total}|%{remote_ip}" -o /dev/null "$TARGET_URL")

IFS='|' read -r dns tcp tls ttfb total remote_ip <<< "$PERF_DATA"

# Convert seconds to milliseconds
dns_ms=$(awk "BEGIN {print $dns * 1000}")
tcp_ms=$(awk "BEGIN {print ($tcp - $dns) * 1000}")
tls_ms=$(awk "BEGIN {print ($tls - $tcp) * 1000}")
ttfb_ms=$(awk "BEGIN {print ($ttfb - $tls) * 1000}")
total_ms=$(awk "BEGIN {print $total * 1000}")

printf "  Egress Gateway IP: ${CYAN}%s${NC}\n" "$remote_ip"
printf "  %-20s : %6.2f ms\n" "DNS Lookup" "$dns_ms"
printf "  %-20s : %6.2f ms\n" "TCP Handshake" "$tcp_ms"
printf "  %-20s : %6.2f ms\n" "TLS Handshake" "$tls_ms"
printf "  %-20s : %6.2f ms\n" "Time to First Byte" "$ttfb_ms"
echo -e "  ------------------------------------"
printf "  %-20s : ${GREEN}%6.2f ms${NC}\n" "Total Round Trip" "$total_ms"

echo -e "${CYAN}====================================================${NC}"
