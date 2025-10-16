# 🧩 Kubernetes Cluster Resource Analyzer

A Bash script that analyzes **real + reserved resources** (CPU & Memory) on Kubernetes nodes.  
It helps identify overcommitted or underutilized nodes in your cluster.

---

## 🚀 Features
- Shows **real usage + reserved (requests)** per node.
- Highlights nodes above 80% or 90% usage (color-coded).
- Works with **any cluster** (Prod, Non-Prod, Dev).
- Compatible with all `kubectl`-based environments.

---

## ⚙️ Requirements
- `kubectl` access to the cluster
- `jq` installed
- `metrics-server` enabled (for `kubectl top`)

---

## 🧾 Usage

### Analyze a specific node group
```bash
./analyze_node_resources.sh nonprod-workload01-xxx
