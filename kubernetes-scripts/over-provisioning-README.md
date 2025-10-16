# Kubernetes Over-Provisioning Analyzer

This Bash script analyzes **resource over-provisioning** in Kubernetes pods by comparing actual vs requested CPU and memory usage.

## 🔍 Features
- Detects inefficient pods consuming less than requested.
- Reports CPU and memory waste.
- Safe for production (read-only).
- Simple output for optimization insights.

## ⚙️ Requirements
- `kubectl`
- `jq`
- Metrics Server installed

## 🚀 Usage
```bash
chmod +x over-provisioning.sh
./over-provisioning.sh           # Non-prod default
./over-provisioning.sh prod-node # Example for production
```

## 🛡️ Safe for Production
This script only **reads** metrics (no changes are made). Perfect for audits and tuning.

---
MIT License © 2025 Seba DevOps