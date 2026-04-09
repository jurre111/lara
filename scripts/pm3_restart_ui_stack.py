#!/usr/bin/env python3

import argparse
import json
import os
import subprocess
import sys
import time
from typing import List, Optional


def _run(cmd: List[str], *, check: bool = True) -> subprocess.CompletedProcess:
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if check and p.returncode != 0:
        sys.stdout.write(p.stdout)
        raise SystemExit(p.returncode)
    return p


def _device_opts(args: argparse.Namespace) -> List[str]:
    opts: List[str] = []
    if args.rsd:
        host, port = args.rsd
        opts += ["--rsd", host, str(port)]
    if args.tunnel is not None:
        # Provide UDID[:PORT] or just UDID. Empty value would be interactive; disallow.
        if args.tunnel == "":
            raise SystemExit("--tunnel requires a UDID (optionally with :PORT)")
        opts += ["--tunnel", args.tunnel]
    if args.mobdev2:
        opts += ["--mobdev2"]
    if args.usbmux:
        opts += ["--usbmux", args.usbmux]
    if args.udid:
        opts += ["--udid", args.udid]
    return opts


def _pm3(*parts: str) -> List[str]:
    return ["pymobiledevice3", *parts]

def _autodetect_udid(usbmux: Optional[str]) -> Optional[str]:
    cmd = _pm3("usbmux", "list")
    if usbmux:
        cmd += ["--usbmux", usbmux]
    p = _run(cmd, check=False)
    out = (p.stdout or "").strip()

    try:
        devices = json.loads(out)
    except Exception:
        return None

    if not isinstance(devices, list) or not devices:
        return None

    udids: List[str] = []
    for d in devices:
        if isinstance(d, dict):
            udid = d.get("udid") or d.get("UDID")
            if isinstance(udid, str) and udid:
                udids.append(udid)

    udids = list(dict.fromkeys(udids))
    if len(udids) == 1:
        return udids[0]
    return None


def _pgrep(device_opts: List[str], expr: str) -> bool:
    cmd = _pm3("processes", "pgrep", *device_opts, expr)
    p = _run(cmd, check=False)
    out = (p.stdout or "").strip()
    # When it finds matches, pymobiledevice3 prints one or more PIDs.
    for tok in out.replace(",", " ").split():
        if tok.isdigit() and int(tok) > 0:
            return True
    return False


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Restart iOS UI stack processes via pymobiledevice3 (SpringBoard/backboardd/frontboardd)."
    )
    ap.add_argument("--udid", default=os.environ.get("PYMOBILEDEVICE3_UDID"))
    ap.add_argument("--tunnel", default=os.environ.get("PYMOBILEDEVICE3_TUNNEL"))
    ap.add_argument("--usbmux", default=os.environ.get("PYMOBILEDEVICE3_USBMUX"))
    ap.add_argument("--mobdev2", action="store_true", help="Discover devices over bonjour/mobdev2 instead of usbmux.")
    ap.add_argument(
        "--rsd",
        nargs=2,
        metavar=("HOST", "PORT"),
        help="RemoteServiceDiscovery host/port (mutually exclusive with --tunnel).",
    )
    ap.add_argument("--wait", type=float, default=30.0, help="Max seconds to wait for respawn.")
    ap.add_argument("--poll", type=float, default=0.5, help="Poll interval while waiting.")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument(
        "--kill",
        action="append",
        default=None,
        help="Process-name expression to kill (repeatable). Default kills frontboardd/FrontBoard, backboardd, SpringBoard.",
    )
    ns = ap.parse_args()

    if ns.rsd and ns.tunnel is not None:
        raise SystemExit("--rsd is mutually exclusive with --tunnel")

    if ns.udid is None and ns.tunnel is None and ns.rsd is None:
        guessed = _autodetect_udid(ns.usbmux)
        if guessed:
            ns.udid = guessed
            print(f"[*] autodetected udid: {ns.udid}")

    dev = _device_opts(ns)

    kill_exprs = ns.kill or ["frontboardd", "FrontBoard", "backboardd", "SpringBoard"]
    kill_cmd = _pm3("developer", "dvt", "pkill", *dev, *kill_exprs)

    print("[*] killing:", ", ".join(kill_exprs))
    if ns.dry_run:
        print("[dry-run]", " ".join(kill_cmd))
        return 0

    _run(kill_cmd, check=False)

    # Wait for SpringBoard to come back; if it's up, UI is usually usable again.
    deadline = time.time() + ns.wait
    while time.time() < deadline:
        if _pgrep(dev, "SpringBoard"):
            print("[+] SpringBoard is running again")
            return 0
        time.sleep(ns.poll)

    print("[-] timeout waiting for SpringBoard to respawn")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
