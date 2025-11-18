#!/bin/bash
journalctl --vacuum=1d
apt-get clean -qq
rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
echo "[$(date)] Cleanup completed" >> /var/log/vpn-cleanup.log
