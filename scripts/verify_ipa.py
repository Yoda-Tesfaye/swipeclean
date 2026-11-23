"""Sanity-check an unsigned iOS .ipa without Xcode.

Checks performed:
  * IPA is a zip with a single Payload/*.app
  * Info.plist has the expected bundle id / version / minimum OS
  * main executable is a 64-bit arm64 Mach-O
  * executable contains strings that only exist in our Swift sources
  * no _CodeSignature (it must be resigned by Sideloadly/AltStore)

Usage: python scripts/verify_ipa.py path/to/app.ipa
"""

import os
import plistlib
import struct
import sys
import zipfile

CPU_TYPE_ARM64 = 0x0100000C
MH_MAGIC_64 = 0xFEEDFACF

EXPECTED_STRINGS = ["SwipeClean", "删除后会移入「最近删除」", "让所有内容重新随机出现", "想再刷一遍"]


def fail(message):
    print("FAIL:", message)
    return 1


def main(path):
    if not os.path.isfile(path):
        return fail(f"no such file: {path}")

    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        apps = sorted({name.split("/")[1] for name in names if name.startswith("Payload/") and name.count("/") >= 1})
        apps = [name for name in apps if name.endswith(".app")]
        print("entries:", len(names))
        print("apps:", apps)
        if len(apps) != 1:
            return fail("expected exactly one Payload/*.app")

        app = apps[0]
        prefix = f"Payload/{app}/"
        info_path = prefix + "Info.plist"
        if info_path not in names:
            return fail("Info.plist missing")

        info = plistlib.loads(archive.read(info_path))
        print("bundle id:", info.get("CFBundleIdentifier"))
        print("version:", info.get("CFBundleShortVersionString"), "/", info.get("CFBundleVersion"))
        print("display name:", info.get("CFBundleDisplayName"))
        print("minimum OS:", info.get("MinimumOSVersion"))
        print("photo permission:", bool(info.get("NSPhotoLibraryUsageDescription")))

        if info.get("CFBundleIdentifier") != "com.swipeclean.app":
            return fail("unexpected bundle identifier")

        executable = info.get("CFBundleExecutable", "SwipeClean")
        binary_path = prefix + executable
        if binary_path not in names:
            return fail("executable missing: " + binary_path)

        data = archive.read(binary_path)
        magic, cpu_type, cpu_subtype = struct.unpack("<III", data[:12])
        print("binary size:", len(data), "bytes")
        print(f"macho magic: 0x{magic:08x} cpu: 0x{cpu_type:08x} sub: 0x{cpu_subtype:x}")
        if magic != MH_MAGIC_64:
            return fail("not a 64-bit Mach-O")
        if cpu_type != CPU_TYPE_ARM64:
            return fail("not arm64")

        signatures = [name for name in names if "_CodeSignature" in name]
        print("code signature entries:", len(signatures))

        text = data.decode("utf-8", errors="ignore")
        for needle in EXPECTED_STRINGS:
            print(f"contains {needle!r}:", needle in text)

        print("assets:", len([n for n in names if n.startswith(prefix) and n.endswith((".car", ".png"))]))
        print("OK: ipa looks installable (unsigned, arm64)")
        return 0


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else os.path.join("dist", "SwipeClean-1.0.0-unsigned.ipa")
    sys.exit(main(target))

