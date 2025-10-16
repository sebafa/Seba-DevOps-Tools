#!/bin/bash
# ======================================================
# 🔍 Kubernetes Node Resource Analyzer
# Autor: Seba
# Analiza recursos reales + reservados en nodos de Kubernetes
# ======================================================

echo "==========================================="
echo "RESOURCE ANALYSIS: REAL + RESERVED"
echo "==========================================="
echo ""

# Node filter (puede pasarse como argumento o dejar vacío para todos)
NODE_FILTER=${1:-""}

echo "Filter: ${NODE_FILTER:-ALL NODES}"
echo ""

# Get node list (usa el filtro si existe)
if [ -n "$NODE_FILTER" ]; then
  NODES=$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name | grep -F "$NODE_FILTER")
else
  NODES=$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name)
fi

# Si no hay nodos, salimos
if [ -z "$NODES" ]; then
  echo "❌ No nodes found matching filter: $NODE_FILTER"
  exit 0
fi

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to convert units to millicores
convert_to_millicores() {
    local value=$1
    if [[ $value =~ ^([0-9]+)m$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ $value =~ ^([0-9]+)$ ]]; then
        echo "$((${BASH_REMATCH[1]} * 1000))"
    else
        echo "0"
    fi
}

# Function to convert memory to Mi
convert_to_mi() {
    local value=$1
    if [[ $value =~ ^([0-9]+)Mi$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ $value =~ ^([0-9]+)Gi$ ]]; then
        echo "$((${BASH_REMATCH[1]} * 1024))"
    elif [[ $value =~ ^([0-9]+)Ki$ ]]; then
        echo "$((${BASH_REMATCH[1]} / 1024))"
    else
        echo "0"
    fi
}

echo "Processing nodes..."
echo ""

# Table header
printf "%-50s %10s %10s %10s %8s | %10s %10s %10s %8s\n" \
    "NODE" "CPU_REAL" "CPU_REQ" "CPU_TOTAL" "%_TOTAL" "MEM_REAL" "MEM_REQ" "MEM_TOTAL" "%_TOTAL"
printf "%.s=" {1..160}
echo ""

total_nodes=0
critical_nodes=0

for node in $NODES; do
    total_nodes=$((total_nodes + 1))
    
    # Get node total capacity
    node_info=$(kubectl get node $node -o json)
    cpu_capacity=$(echo "$node_info" | jq -r '.status.capacity.cpu' | sed 's/"//g')
    mem_capacity=$(echo "$node_info" | jq -r '.status.capacity.memory' | sed 's/Ki//g')
    
    cpu_capacity_m=$(convert_to_millicores "$cpu_capacity")
    mem_capacity_mi=$((mem_capacity / 1024))
    
    # Get real usage (metrics)
    real_metrics=$(kubectl top node $node --no-headers 2>/dev/null)
    cpu_real=$(echo "$real_metrics" | awk '{print $2}')
    mem_real=$(echo "$real_metrics" | awk '{print $4}')
    
    cpu_real_m=$(convert_to_millicores "$cpu_real")
    mem_real_mi=$(convert_to_mi "$mem_real")
    
    # Get reserved resources (requests)
    pods_on_node=$(kubectl get pods --all-namespaces --field-selector spec.nodeName=$node -o json)
    
    cpu_requests=0
    mem_requests=0
    
    # Sum all pod requests on the node
    while IFS= read -r container; do
        cpu_req=$(echo "$container" | jq -r '.resources.requests.cpu // "0"' | sed 's/"//g')
        mem_req=$(echo "$container" | jq -r '.resources.requests.memory // "0"' | sed 's/"//g')
        
        cpu_req_m=$(convert_to_millicores "$cpu_req")
        mem_req_mi=$(convert_to_mi "$mem_req")
        
        cpu_requests=$((cpu_requests + cpu_req_m))
        mem_requests=$((mem_requests + mem_req_mi))
    done < <(echo "$pods_on_node" | jq -c '.items[].spec.containers[]')
    
    # Calculate totals (real + reserved)
    cpu_total=$((cpu_real_m + cpu_requests))
    mem_total=$((mem_real_mi + mem_requests))
    
    # Calculate percentages
    cpu_pct=$((cpu_total * 100 / cpu_capacity_m))
    mem_pct=$((mem_total * 100 / mem_capacity_mi))
    
    # Determine color based on criticality
    color=$GREEN
    if [ $cpu_pct -gt 80 ] || [ $mem_pct -gt 80 ]; then
        color=$YELLOW
        critical_nodes=$((critical_nodes + 1))
    fi
    if [ $cpu_pct -gt 90 ] || [ $mem_pct -gt 90 ]; then
        color=$RED
    fi
    
    # Display result
    printf "${color}%-50s %9sm %9sm %9sm %7s%% | %9sMi %9sMi %9sMi %7s%%${NC}\n" \
        "$node" "$cpu_real_m" "$cpu_requests" "$cpu_total" "$cpu_pct" \
        "$mem_real_mi" "$mem_requests" "$mem_total" "$mem_pct"
done

echo ""
echo "==========================================="
echo "SUMMARY"
echo "==========================================="
echo "Total nodes analyzed: $total_nodes"
echo "Nodes with >80% resources (real+reserved): $critical_nodes"
echo ""
echo "Legend:"
echo "  CPU_REAL  = Current CPU usage"
echo "  CPU_REQ   = CPU reserved by requests"
echo "  CPU_TOTAL = Real + Reserved"
echo "  MEM_REAL  = Current memory usage"
echo "  MEM_REQ   = Memory reserved by requests"
echo "  MEM_TOTAL = Real + Reserved"
echo ""
echo -e "${GREEN}Green${NC}  = <80% | ${YELLOW}Yellow${NC} = 80–90% | ${RED}Red${NC} = >90%"
