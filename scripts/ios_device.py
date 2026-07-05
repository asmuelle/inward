#!/usr/bin/env python3
"""Resolve a usable iOS device for `just run-on-device`.

Prints "<coredevice-id> <hardware-udid>" for the best-matching iPhone/iPad, or
nothing (exit 1) if none is reachable. The CoreDevice id drives devicectl
install/launch; the hardware UDID drives the xcodebuild device destination.

A device is usable when it is paired and either:
  - its secure tunnel is already `connected`, or
  - it is `wired` (plugged in) — devicectl establishes the tunnel on demand.

The tunnel idles to `disconnected` within seconds of inactivity, so requiring
it to be `connected` at list time wrongly rejects a perfectly usable wired
phone. The subsequent xcodebuild/devicectl calls re-establish it and hold it
for the whole install/launch. A `connected` device is still preferred when more
than one matches.

An optional argv[1] name fragment narrows the match (e.g. "Excalibur").
"""
import json
import os
import subprocess
import sys
import tempfile
from typing import Any


def is_phone_or_pad(device: dict[str, Any]) -> bool:
    product = device.get("hardwareProperties", {}).get("productType", "") or ""
    return "iPhone" in product or "iPad" in product


def usable(device: dict[str, Any]) -> bool:
    """Paired, and either tunneled now or wired (tunnel comes up on demand)."""
    conn = device.get("connectionProperties", {})
    if conn.get("pairingState") != "paired":
        return False
    return conn.get("tunnelState") == "connected" or conn.get("transportType") == "wired"


def tunnel_rank(device: dict[str, Any]) -> int:
    """Prefer an already-connected tunnel over a wired-but-idle one."""
    return 0 if device.get("connectionProperties", {}).get("tunnelState") == "connected" else 1


def main() -> int:
    name = sys.argv[1] if len(sys.argv) > 1 else ""
    # `just` takes positional args, so `just run-on-device name=Excalibur` passes
    # the literal "name=Excalibur" here. Tolerate that common habit by stripping a
    # leading `name=` (or `device=`) so both invocation styles resolve the device.
    for prefix in ("name=", "device="):
        if name.startswith(prefix):
            name = name[len(prefix):]
            break

    fd, path = tempfile.mkstemp(suffix=".json")
    os.close(fd)
    try:
        subprocess.run(
            ["xcrun", "devicectl", "list", "devices", "--json-output", path],
            check=True,
            capture_output=True,
        )
        devices = json.load(open(path))["result"]["devices"]
    finally:
        os.unlink(path)

    def matches_name(device: dict[str, Any]) -> bool:
        device_name = device.get("deviceProperties", {}).get("name", "") or ""
        return not name or name in device_name

    candidates = [
        device
        for device in devices
        if is_phone_or_pad(device) and usable(device) and matches_name(device)
    ]
    if not candidates:
        return 1

    best = min(candidates, key=tunnel_rank)
    print(best["identifier"], best["hardwareProperties"]["udid"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
