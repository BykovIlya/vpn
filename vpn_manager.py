#!/usr/bin/env python3
import os, sys, json, subprocess, argparse, logging, re, shutil
from pathlib import Path
from datetime import datetime
from typing import Tuple, Optional, Dict

try:
    from dotenv import load_dotenv  # type: ignore
except Exception:
    load_dotenv = None  # optional dependency

# ---------------- Configuration ----------------
DEFAULTS = {
    "WG_INTERFACE": "wg0",
    "WG_DIR": "/etc/wireguard",
    "WG_CLIENTS_DIR": "/etc/wireguard/clients",
    "WG_PORT": "51820",
    "WG_NETWORK": "10.0.0.0/24",
    "WG_DNS": "8.8.8.8, 1.1.1.1",
    "LOG_LEVEL": "INFO",
    "LOG_FILE": "",
}

def env(key: str, fallback: str) -> str:
    return os.getenv(key, fallback)

def load_env_if_present() -> None:
    # load .env from CWD or /etc/wireguard
    candidates = [Path.cwd() / ".env", Path("/etc/wireguard/.env")]
    if load_dotenv:
        for p in candidates:
            if p.exists():
                load_dotenv(dotenv_path=str(p), override=False)

def setup_logging(level: str, log_file: Optional[str], quiet: bool, verbose: bool) -> None:
    if verbose:
        level = "DEBUG"
    elif quiet:
        level = "WARNING"
    lvl = getattr(logging, level.upper(), logging.INFO)
    handlers = [logging.StreamHandler(sys.stdout)]
    if log_file:
        handlers.append(logging.FileHandler(log_file))
    logging.basicConfig(
        level=lvl,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=handlers,
    )

def run_cmd(cmd: str, timeout: int = 30) -> Tuple[int, str, str]:
    proc = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
    return proc.returncode, proc.stdout.strip(), proc.stderr.strip()

def require_root() -> None:
    if os.geteuid() != 0:
        logging.critical("This command must be run as root (sudo).")
        sys.exit(1)

def validate_device_name(name: str) -> None:
    if not name or not re.match(r"^[a-zA-Z0-9_-]+$", name):
        raise ValueError("Invalid device name. Allowed: letters, numbers, underscore, hyphen.")

class VPNManager:
    def __init__(self, cfg: Dict[str, str]) -> None:
        self.interface = cfg["WG_INTERFACE"]
        self.config_dir = Path(cfg["WG_DIR"])
        self.clients_dir = Path(cfg["WG_CLIENTS_DIR"])
        self.port = int(cfg["WG_PORT"])
        self.network = cfg["WG_NETWORK"]
        self.dns = cfg["WG_DNS"]
        self.wg_config = self.config_dir / f"{self.interface}.conf"
        self.credentials = self.config_dir / ".credentials"

    def status(self) -> Dict[str, str]:
        code, out, err = run_cmd(f"wg show {self.interface}")
        disk = shutil.disk_usage("/")
        mem_used = run_cmd("free -h | awk 'NR==2 {print $3 \"/\" $2}'")[1]
        return {
            "success": str(code == 0).lower(),
            "wg": out or err,
            "disk_free": f"{round(disk.free/1024/1024/1024,1)}G",
            "memory": mem_used,
        }

    def list_devices(self) -> Dict[str, list]:
        if not self.wg_config.exists():
            return {"devices": []}
        devices = []
        with open(self.wg_config, "r", encoding="utf-8") as f:
            name = None
            for line in f:
                if line.startswith("# Device: "):
                    name = line.strip().split(": ", 1)[1]
                    devices.append(name)
        return {"devices": devices}

    def _next_ip(self) -> str:
        last = 1
        if self.wg_config.exists():
            import re
            ips = []
            with open(self.wg_config, "r", encoding="utf-8") as f:
                for line in f:
                    m = re.search(r'AllowedIPs\s*=\s*10\.0\.0\.(\d+)/32', line)
                    if m:
                        ips.append(int(m.group(1)))
            if ips:
                last = max(ips)
        nxt = last + 1
        if nxt > 254:
            raise RuntimeError("IP pool exhausted in 10.0.0.0/24")
        return f"10.0.0.{nxt}"

    def add_device(self, device_name: str) -> Dict[str, str]:
        validate_device_name(device_name)
        if not self.wg_config.exists() or not self.credentials.exists():
            raise RuntimeError(f"WireGuard not initialized. Missing {self.wg_config} or {self.credentials}")

        logging.info("Generating keys...")
        code, priv, err = run_cmd("wg genkey")
        if code != 0:
            raise RuntimeError(f"Failed to generate key: {err}")
        code, pub, err = run_cmd(f"echo '{priv}' | wg pubkey")
        if code != 0:
            raise RuntimeError(f"Failed to derive public key: {err}")

        device_ip = self._next_ip()
        logging.info("Assigning IP %s", device_ip)

        # Get server pubkey and endpoint ip
        envs = {}
        with open(self.credentials, "r", encoding="utf-8") as c:
            for line in c:
                if "=" in line:
                    k, v = line.strip().split("=", 1)
                    envs[k] = v
        server_pub = envs.get("SERVER_PUBKEY", "")
        server_ip = envs.get("SERVER_IP", "0.0.0.0")

        # Append peer to wg config
        with open(self.wg_config, "a", encoding="utf-8") as f:
            f.write(f"\n# Device: {device_name}\n[Peer]\nPublicKey = {pub.strip()}\nAllowedIPs = {device_ip}/32\n")

        # Restart interface
        code, _, err = run_cmd(f"systemctl restart wg-quick@{self.interface}")
        if code != 0:
            raise RuntimeError(f"Failed to restart WireGuard: {err}")

        self.clients_dir.mkdir(parents=True, exist_ok=True)
        client_conf_path = self.clients_dir / f"{device_name}.conf"
        with open(client_conf_path, "w", encoding="utf-8") as cf:
            cf.write(
                f"[Interface]\nPrivateKey = {priv.strip()}\nAddress = {device_ip}/24\nDNS = {self.dns}\nMTU = 1420\n\n"
                f"[Peer]\nPublicKey = {server_pub}\nAllowedIPs = 0.0.0.0/0, ::/0\nEndpoint = {server_ip}:{self.port}\nPersistentKeepalive = 20\n"
            )
        os.chmod(client_conf_path, 0o600)
        return {"device": device_name, "ip": device_ip, "config": str(client_conf_path)}

    def remove_device(self, device_name: str) -> Dict[str, str]:
        validate_device_name(device_name)
        if not self.wg_config.exists():
            raise RuntimeError(f"WireGuard config not found: {self.wg_config}")

        # Remove block between '# Device: name' and next blank line
        lines = self.wg_config.read_text(encoding="utf-8").splitlines()
        new_lines = []
        skip = False
        for i, line in enumerate(lines):
            if line.strip() == f"# Device: {device_name}":
                skip = True
                continue
            if skip and line.strip() == "":
                skip = False
                continue
            if not skip:
                new_lines.append(line)
        self.wg_config.write_text("\n".join(new_lines) + "\n", encoding="utf-8")

        run_cmd(f"systemctl restart wg-quick@{self.interface}")

        client_conf = self.clients_dir / f"{device_name}.conf"
        if client_conf.exists():
            client_conf.unlink()

        return {"removed": device_name}

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="vpn_manager.py",
        description="WireGuard VPN Manager (senior-grade CLI). Requires root.",
    )
    p.add_argument("--json", action="store_true", help="Print machine-readable JSON output")
    p.add_argument("-q", "--quiet", action="store_true", help="Reduce console verbosity (WARNING level)")
    p.add_argument("-v", "--verbose", action="store_true", help="Increase console verbosity (DEBUG level)")
    p.add_argument("--log-file", default=None, help="Optional log file path")

    sub = p.add_subparsers(dest="command", required=True)

    a = sub.add_parser("status", help="Show WireGuard status, disk and memory usage")
    a = sub.add_parser("list", help="List known devices from the server config")

    a = sub.add_parser("add", help="Add a new device (peer) and generate client config")
    a.add_argument("device", help="Device name (letters, numbers, underscore, hyphen)")

    r = sub.add_parser("remove", help="Remove an existing device (peer)")
    r.add_argument("device", help="Device name to remove")

    return p

def main() -> None:
    load_env_if_present()

    # Merge config
    cfg = {k: env(k, v) for k, v in DEFAULTS.items()}

    parser = build_parser()
    args = parser.parse_args()

    setup_logging(cfg["LOG_LEVEL"], args.log_file or (env("LOG_FILE", "")), args.quiet, args.verbose)

    try:
        require_root()
        mgr = VPNManager(cfg)

        if args.command == "status":
            out = mgr.status()
            if args.json:
                print(json.dumps(out, ensure_ascii=False))
            else:
                print("=== WireGuard Status ({}): ===".format(cfg["WG_INTERFACE"]))
                print(out.get("wg", ""))
                print("\nDisk free:", out["disk_free"])
                print("Memory:   ", out["memory"])

        elif args.command == "list":
            out = mgr.list_devices()
            if args.json:
                print(json.dumps(out, ensure_ascii=False))
            else:
                if not out["devices"]:
                    print("No devices found.")
                else:
                    print("Devices:")
                    for d in out["devices"]:
                        print(" -", d)

        elif args.command == "add":
            out = mgr.add_device(args.device)
            if args.json:
                print(json.dumps(out, ensure_ascii=False))
            else:
                print("Device added.")
                print(" Name:  ", out["device"])
                print(" IP:    ", out["ip"])
                print(" Config:", out["config"])

        elif args.command == "remove":
            out = mgr.remove_device(args.device)
            if args.json:
                print(json.dumps(out, ensure_ascii=False))
            else:
                print(f"Removed device: {out['removed']}")

    except KeyboardInterrupt:
        logging.error("Interrupted by user.")
        sys.exit(130)
    except Exception as e:
        logging.critical(str(e))
        if os.getenv("DEBUG"):
            raise
        sys.exit(1)

if __name__ == "__main__":
    main()
