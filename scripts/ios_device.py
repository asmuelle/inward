#!/usr/bin/env python3
"""Resolve a usable iOS device for `just run-on-device`.

Prints "<coredevice-id> <hardware-udid>" for the best-matching iPhone/iPad, or
nothing (exit 1) if none is reachable. The CoreDevice id drives devicectl
install/launch; the hardware UDID drives the xcodebuild device destination.

A device is usable when it is paired. devicectl establishes the secure tunnel
on demand for the actual install/launch, whether the phone is `wired` (plugged
in) or reachable over `localNetwork` (Wi-Fi).

The tunnel idles to `disconnected` within seconds of inactivity, so requiring
it to be `connected` at list time wrongly rejects a perfectly usable phone —
including a Wi-Fi device whose tunnel is simply idle. The subsequent
xcodebuild/devicectl calls re-establish it and hold it for the whole
install/launch. When several devices match we still prefer the one with the
least setup work: an already-`connected` tunnel first, then `wired`, then
`localNetwork`.

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
    """Paired is enough — devicectl brings the tunnel up on demand."""
    return device.get("connectionProperties", {}).get("pairingState") == "paired"


def tunnel_rank(device: dict[str, Any]) -> int:
    """Least setup first: connected tunnel, then wired, then localNetwork."""
    conn = device.get("connectionProperties", {})
    if conn.get("tunnelState") == "connected":
        return 0
    return 1 if conn.get("transportType") == "wired" else 2


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
