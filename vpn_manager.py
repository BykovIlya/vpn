#!/usr/bin/env python3
import os, sys, json, subprocess, argparse
from pathlib import Path
from datetime import datetime
import ipaddress, logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class VPNManager:
    def __init__(self):
        self.config_dir = Path("/etc/wireguard")
        self.clients_dir = self.config_dir / "clients"
        self.interface = "wg0"
    
    def _run_cmd(self, cmd):
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    
    def add_device(self, device_name):
        print(f"Adding {device_name}...")
        return {"success": True, "device": device_name}
    
    def status(self):
        code, output, _ = self._run_cmd(f"wg show {self.interface}")
        return {"success": code == 0, "output": output}

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command")
    add_parser = subparsers.add_parser("add")
    add_parser.add_argument("device")
    subparsers.add_parser("status")
    
    args = parser.parse_args()
    manager = VPNManager()
    
    if args.command == "add":
        print(json.dumps(manager.add_device(args.device)))
    elif args.command == "status":
        print(json.dumps(manager.status()))
