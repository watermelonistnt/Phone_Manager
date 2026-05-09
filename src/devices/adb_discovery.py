from __future__ import annotations

from dataclasses import dataclass
import subprocess


@dataclass(frozen=True)
class Device:
    serial: str
    state: str


def discover_devices() -> list[Device]:
    result = subprocess.run(
        ["adb", "devices"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return []

    devices: list[Device] = []
    for line in result.stdout.splitlines()[1:]:
        if not line.strip():
            continue
        parts = line.split()
        if len(parts) >= 2:
            devices.append(Device(serial=parts[0], state=parts[1]))
    return devices
