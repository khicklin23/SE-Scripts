#!/bin/bash

# API Endpoint
URL="https://gateway.gslb.goskope.com/api/v0.1/footprint/zlury2HGBaFogNb3iQsK"

# Make the API request and store the response
response=$(curl -s "$URL")

# Extract and process JSON without jq
echo "POP | IP 1 | Time (ms)"
echo "================================="

# Extract the "pops" section
pops=$(echo "$response" | sed -n 's/.*"pops":\[//p' | sed 's/]}}//')

# Initialize counter
count=0

echo "$pops" | tr -d '\n' | sed 's/},{/}\n{/g' | while IFS= read -r pop; do
    # Extract name
    name=$(echo "$pop" | sed -n 's/.*"name":"\([^"]*\).*/\1/p')
    
    # Extract RTT endpoint IPs
    ips=($(echo "$pop" | grep -o '"ip":"[^"]*"' | sed 's/"ip":"//g' | sed 's/"//g'))
    
    # Perform ICMP ping to IP[0] and extract time value
    if [ -n "${ips[0]}" ]; then
        time_ms=$(ping -c 1 "${ips[0]}" 2>/dev/null | grep -o 'time=[0-9.]* ms' | cut -d '=' -f2)
    else
        time_ms="N/A"
    fi
    
    # Ensure the IPs are displayed in a single line with a maximum of 2 per row
    if [ -n "$name" ]; then
        printf "%s | %s | %s\n" "$name" "${ips[0]:-}" "$time_ms"
    fi
    
    # Increment counter and break after 10 entries
    count=$((count+1))
    if [ "$count" -ge 20 ]; then
        break
    fi
done
