#!/bin/bash
echo "=== WireGuard Status ==="
sudo wg show wg0
echo ""
echo "Диск: $(df -h / | awk 'NR==2 {print $4}')"
echo "Память: $(free -h | awk 'NR==2 {print $3 "/" $2}')"
