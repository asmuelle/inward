#!/usr/bin/env python3
"""Resolve a connected iOS device for `just run-on-device`.

Prints "<coredevice-id> <hardware-udid>" for the first connected iPhone/iPad,
or nothing (exit 1) if none is attached. The CoreDevice id drives devicectl
install/launch; the hardware UDID drives the xcodebuild device destination.

An optional argv[1] name fragment narrows the match (e.g. "Excalibur").
"""
import json
import os
import subprocess
import sys
import tempfile


def main() -> int:
    name = sys.argv[1] if len(sys.argv) > 1 else ""

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

    for device in devices:
        hardware = device.get("hardwareProperties", {})
        product = hardware.get("productType", "") or ""
        if "iPhone" not in product and "iPad" not in product:
            continue
        if device.get("connectionProperties", {}).get("tunnelState") != "connected":
            continue
        device_name = device.get("deviceProperties", {}).get("name", "") or ""
        if name and name not in device_name:
            continue
        print(device["identifier"], hardware["udid"])
        return 0

    return 1


if __name__ == "__main__":
    sys.exit(main())
