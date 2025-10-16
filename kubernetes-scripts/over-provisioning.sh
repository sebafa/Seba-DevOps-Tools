#!/bin/bash

# Script to identify pods with excessive resource requests vs actual usage
# This helps find optimization opportunities

echo "============================================================"
echo "OVER-PROVISIONED PODS ANALYSIS"
echo "Finding pods with excessive requests vs real usage"
echo "============================================================"
echo ""

# Node filter (can be passed as an argument)
NODE_FILTER=${1:-"nonprod-workload01-default"}

echo "Using node filter: $NODE_FILTER"
echo ""

# Thresholds for flagging over-provisioned pods
CPU_WASTE_THRESHOLD=500    # Flag if wasting more than 500m CPU
MEM_WASTE_THRESHOLD=1024   # Flag if wasting more than 1Gi (1024Mi)
RATIO_THRESHOLD=3          # Flag if requests are 3x+ higher than usage

# Function to convert CPU to millicores
convert_cpu_to_millicores() {
    local value=$1
    if [[ $value =~ ^([0-9]+)m$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ $value =~ ^([0-9.]+)$ ]]; then
        echo "$((${BASH_REMATCH[1]%.*} * 1000))"
    else
        echo "0"
    fi
}

# Function to convert memory to Mi
convert_mem_to_mi() {
    local value=$1
    if [[ $value =~ ^([0-9]+)Mi$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ $value =~ ^([0-9]+)Gi$ ]]; then
        echo "$((${BASH_REMATCH[1]} * 1024))"
    elif [[ $value =~ ^([0-9]+)Ki$ ]]; then
        echo "$((${BASH_REMATCH[1]} / 1024))"
    elif [[ $value =~ ^([0-9]+)M$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ $value =~ ^([0-9]+)G$ ]]; then
        echo "$((${BASH_REMATCH[1]} * 1024))"
    else
        echo "0"
    fi
}

echo "Collecting pod metrics and requests..."
echo "This may take a few minutes..."
echo ""

# Get all nodes matching filter
NODES=$(kubectl get nodes --no-headers | grep "$NODE_FILTER" | awk '{print $1}')

# Temporary files for data collection
TEMP_FILE=$(mktemp)
SUMMARY_FILE=$(mktemp)

total_pods=0
flagged_pods=0

# Collect data for all pods
for node in $NODES; do
    # Get pods on this node
    pods=$(kubectl get pods --all-namespaces --field-selector spec.nodeName=$node -o json)
    
    # Process each pod
    echo "$pods" | jq -r '.items[] | 
        "\(.metadata.namespace)|\(.metadata.name)|\(.spec.nodeName)|\(.spec.containers[0].name)|\(.spec.containers[0].resources.requests.cpu // "0")|\(.spec.containers[0].resources.requests.memory // "0")"' | \
    while IFS='|' read -r namespace pod_name node_name container_name cpu_req mem_req; do
        total_pods=$((total_pods + 1))
        
        # Get real usage from metrics
        usage_line=$(kubectl top pod $pod_name -n $namespace --no-headers 2>/dev/null | head -1)
        
        if [ -z "$usage_line" ]; then
            continue
        fi
        
        cpu_usage=$(echo "$usage_line" | awk '{print $2}')
        mem_usage=$(echo "$usage_line" | awk '{print $3}')
        
        # Convert to standard units
        cpu_req_m=$(convert_cpu_to_millicores "$cpu_req")
        cpu_usage_m=$(convert_cpu_to_millicores "$cpu_usage")
        mem_req_mi=$(convert_mem_to_mi "$mem_req")
        mem_usage_mi=$(convert_mem_to_mi "$mem_usage")
        
        # Skip if no requests defined
        if [ "$cpu_req_m" -eq 0 ] && [ "$mem_req_mi" -eq 0 ]; then
            continue
        fi
        
        # Calculate waste
        cpu_waste=$((cpu_req_m - cpu_usage_m))
        mem_waste=$((mem_req_mi - mem_usage_mi))
        
        # Calculate ratios (avoid division by zero)
        if [ "$cpu_usage_m" -gt 0 ]; then
            cpu_ratio=$((cpu_req_m * 100 / cpu_usage_m))
        else
            cpu_ratio=999
        fi
        
        if [ "$mem_usage_mi" -gt 0 ]; then
            mem_ratio=$((mem_req_mi * 100 / mem_usage_mi))
        else
            mem_ratio=999
        fi
        
        # Calculate efficiency percentages
        if [ "$cpu_req_m" -gt 0 ]; then
            cpu_efficiency=$((cpu_usage_m * 100 / cpu_req_m))
        else
            cpu_efficiency=0
        fi
        
        if [ "$mem_req_mi" -gt 0 ]; then
            mem_efficiency=$((mem_usage_mi * 100 / mem_req_mi))
        else
            mem_efficiency=0
        fi
        
        # Flag if over-provisioned
        flag=0
        if [ "$cpu_waste" -gt "$CPU_WASTE_THRESHOLD" ] || [ "$mem_waste" -gt "$MEM_WASTE_THRESHOLD" ]; then
            flag=1
        fi
        
        if [ "$cpu_ratio" -gt $((RATIO_THRESHOLD * 100)) ] || [ "$mem_ratio" -gt $((RATIO_THRESHOLD * 100)) ]; then
            flag=1
        fi
        
        if [ "$flag" -eq 1 ]; then
            flagged_pods=$((flagged_pods + 1))
            echo "$namespace|$pod_name|$cpu_req_m|$cpu_usage_m|$cpu_waste|$cpu_efficiency|$mem_req_mi|$mem_usage_mi|$mem_waste|$mem_efficiency" >> $TEMP_FILE
        fi
    done
done

# Sort by CPU waste (descending)
sort -t'|' -k5 -nr $TEMP_FILE > $SUMMARY_FILE

echo "============================================================"
echo "TOP OVER-PROVISIONED PODS (by CPU waste)"
echo "============================================================"
echo ""
printf "%-40s %-30s %10s %10s %10s %8s | %10s %10s %10s %8s\n" \
    "NAMESPACE" "POD" "CPU_REQ" "CPU_USED" "CPU_WASTE" "EFF%" "MEM_REQ" "MEM_USED" "MEM_WASTE" "EFF%"
printf "%.s=" {1..160}
echo ""

# Display top 30 offenders
head -30 $SUMMARY_FILE | while IFS='|' read -r namespace pod cpu_req cpu_usage cpu_waste cpu_eff mem_req mem_usage mem_waste mem_eff; do
    # Color coding based on efficiency
    if [ "$cpu_eff" -lt 20 ] || [ "$mem_eff" -lt 20 ]; then
        color='\033[0;31m'  # Red
    elif [ "$cpu_eff" -lt 50 ] || [ "$mem_eff" -lt 50 ]; then
        color='\033[1;33m'  # Yellow
    else
        color='\033[0;32m'  # Green
    fi
    nc='\033[0m'
    
    printf "${color}%-40s %-30s %9sm %9sm %9sm %7s%% | %9sMi %9sMi %9sMi %7s%%${nc}\n" \
        "$namespace" "$pod" "$cpu_req" "$cpu_usage" "$cpu_waste" "$cpu_eff" \
        "$mem_req" "$mem_usage" "$mem_waste" "$mem_eff"
done

echo ""
echo "============================================================"
echo "SUMMARY"
echo "============================================================"

# Calculate totals
total_cpu_waste=0
total_mem_waste=0

while IFS='|' read -r namespace pod cpu_req cpu_usage cpu_waste cpu_eff mem_req mem_usage mem_waste mem_eff; do
    total_cpu_waste=$((total_cpu_waste + cpu_waste))
    total_mem_waste=$((total_mem_waste + mem_waste))
done < $SUMMARY_FILE

# Convert to cores and Gi for readability
total_cpu_waste_cores=$((total_cpu_waste / 1000))
total_mem_waste_gi=$((total_mem_waste / 1024))

echo "Total pods analyzed: $total_pods"
echo "Over-provisioned pods found: $flagged_pods"
echo ""
echo "Total wasted resources across flagged pods:"
echo "  CPU:    ${total_cpu_waste}m (${total_cpu_waste_cores} cores)"
echo "  Memory: ${total_mem_waste}Mi (${total_mem_waste_gi}Gi)"
echo ""
echo "Potential savings if optimized:"
echo "  - Could free up ~${total_cpu_waste_cores} CPU cores"
echo "  - Could free up ~${total_mem_waste_gi}Gi of memory"
echo ""
echo "Legend:"
echo "  CPU_REQ   = CPU requested by pod"
echo "  CPU_USED  = Actual CPU usage"
echo "  CPU_WASTE = Difference (requested - used)"
echo "  EFF%      = Efficiency (used/requested * 100)"
echo ""
echo "Recommendations:"
echo "  1. Review pods with <20% efficiency (RED) - highest priority"
echo "  2. Consider reducing requests to 1.5-2x actual usage"
echo "  3. Use VPA (Vertical Pod Autoscaler) for automatic optimization"
echo "  4. Monitor for 7-14 days before making changes"
echo ""
echo "Next steps:"
echo "  # Get detailed pod info:"
echo "  kubectl describe pod <POD_NAME> -n <NAMESPACE>"
echo ""
echo "  # Check historical usage (if Prometheus available):"
echo "  kubectl top pod <POD_NAME> -n <NAMESPACE> --containers"

# Cleanup
rm -f $TEMP_FILE $SUMMARY_FILE
