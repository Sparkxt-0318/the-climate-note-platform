#!/usr/bin/env python3
"""Build/test the real app and capture production SwiftUI views on an isolated simulator.

Requires macOS, Xcode, and an installed iOS Simulator runtime. No signing needed.
Run from any directory: python3 scripts/native_qa.py
"""
import argparse
import datetime
import hashlib
import json
import pathlib
import platform
import plistlib
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
BUNDLE = "com.theclimatenote.app"
DEFAULT_DEVICES = ["iPhone SE (3rd generation)", "iPhone 16", "iPad Pro 13-inch (M4)"]
SCENES = ["feed", "feed-image-loading", "feed-image-error", "story", "story-visual", "story-no-generation", "summary",
          "actions", "action-selected", "reflection", "reflection-keyboard", "save-queued", "save-error", "save-synced", "progress",
          "journal-empty", "journal-guest", "account", "privacy", "signin-unavailable", "feed-loading",
          "feed-refreshing", "feed-stale", "feed-empty", "feed-error", "impact-loading",
          "impact-threshold", "impact-populated", "impact-stale", "impact-error"]


def run(args, timeout=180, check=True):
    result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
    if check and result.returncode:
        raise RuntimeError(f"Command failed: {' '.join(args)}\n{result.stdout}\n{result.stderr}")
    return result


def add_hashes(manifest):
    """Record every source and project input that can affect captured evidence."""
    inputs = []
    inputs.extend(sorted((ROOT / "ClimateNote").rglob("*.swift")))
    inputs.extend(sorted((ROOT / "ClimateNote").rglob("Info.plist")))
    inputs.extend(sorted((ROOT / "ClimateNote" / "Resources").rglob("*")))
    project = ROOT / "ClimateNote.xcodeproj" / "project.pbxproj"
    package = ROOT / "ClimateNote.xcodeproj" / "project.xcworkspace" / "xcshareddata" / "swiftpm" / "Package.resolved"
    inputs.extend([project, package])
    for path in inputs:
        if path.is_file():
            manifest["inputSHA256"][str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", action="append", dest="devices",
                        help="Exact installed Simulator device type name. Repeat to override the default small, standard, and iPad set.")
    parser.add_argument("--runtime", help="Installed runtime identifier; defaults to newest available iOS")
    parser.add_argument("--output", type=pathlib.Path, help="New output directory; refuses existing directories")
    args = parser.parse_args()
    if platform.system() != "Darwin":
        parser.error("Native QA requires macOS and Xcode. No build or screenshots were produced.")

    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out = (args.output or ROOT / "review" / "native" / stamp).resolve()
    out.mkdir(parents=True, exist_ok=False)
    requested_devices = args.devices or DEFAULT_DEVICES
    manifest = {"createdAt": stamp, "status": "running", "devices": requested_devices,
                "captures": [], "inputSHA256": {}}
    add_hashes(manifest)
    udids = []
    try:
        manifest["xcode"] = run(["xcodebuild", "-version"]).stdout.strip()
        devices = json.loads(run(["xcrun", "simctl", "list", "devicetypes", "--json"]).stdout)["devicetypes"]
        selected_devices = [next((d for d in devices if d["name"] == name), None) for name in requested_devices]
        if any(device is None for device in selected_devices):
            names = ", ".join(d["name"] for d in devices if d["name"].startswith("iPhone"))
            unavailable = ", ".join(name for name, device in zip(requested_devices, selected_devices) if device is None)
            raise RuntimeError(f"Device type unavailable: {unavailable}. Choose --device from: {names}")
        runtimes = json.loads(run(["xcrun", "simctl", "list", "runtimes", "--json"]).stdout)["runtimes"]
        runtimes = [r for r in runtimes if r.get("isAvailable") and ".iOS-" in r["identifier"]]
        if args.runtime:
            runtime = next((r for r in runtimes if r["identifier"] == args.runtime), None)
        else:
            runtime = max(runtimes, key=lambda r: tuple(int(n) for n in r["version"].split(".")), default=None)
        if runtime is None:
            raise RuntimeError("No matching installed iOS runtime. Install one in Xcode Settings > Components.")
        manifest["runtime"] = runtime["identifier"]
        first_device = selected_devices[0]
        first_udid = run(["xcrun", "simctl", "create", f"ClimateNote-QA-{stamp}-0", first_device["identifier"], runtime["identifier"]]).stdout.strip()
        udids.append(first_udid)
        manifest["simulatorUDIDs"] = [first_udid]
        run(["xcrun", "simctl", "boot", first_udid])
        run(["xcrun", "simctl", "bootstatus", first_udid, "-b"], timeout=300)
        derived = out / "DerivedData"
        command = ["xcodebuild", "test", "-project", "ClimateNote.xcodeproj", "-scheme", "ClimateNote",
                   "-configuration", "Debug", "-destination", f"platform=iOS Simulator,id={first_udid}",
                   "-derivedDataPath", str(derived), "-resultBundlePath", str(out / "Tests.xcresult"),
                   "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO"]
        print("Building and running XCTest on the isolated simulator…", flush=True)
        with (out / "xcodebuild.log").open("w", encoding="utf-8") as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=1800)
        if result.returncode:
            raise RuntimeError(f"Xcode build/test failed; inspect {out / 'xcodebuild.log'}")
        manifest["buildAndTests"] = "passed"
        products = derived / "Build" / "Products" / "Debug-iphonesimulator"
        apps = []
        for candidate in products.glob("*.app"):
            with (candidate / "Info.plist").open("rb") as info:
                if plistlib.load(info).get("CFBundleIdentifier") == BUNDLE:
                    apps.append(candidate)
        if len(apps) != 1:
            raise RuntimeError(f"Expected one compiled app with bundle ID {BUNDLE}; found {len(apps)}.")
        app = apps[0]
        for index, device in enumerate(selected_devices):
            if index == 0:
                udid = first_udid
            else:
                udid = run(["xcrun", "simctl", "create", f"ClimateNote-QA-{stamp}-{index}", device["identifier"], runtime["identifier"]]).stdout.strip()
                udids.append(udid)
                manifest["simulatorUDIDs"].append(udid)
                run(["xcrun", "simctl", "boot", udid])
                run(["xcrun", "simctl", "bootstatus", udid, "-b"], timeout=300)
            device_folder = out / device["name"].replace(" ", "-").replace("(", "").replace(")", "").lower()
            device_folder.mkdir()
            run(["xcrun", "simctl", "install", udid, str(app)])
            run(["xcrun", "simctl", "status_bar", udid, "override", "--time", "9:41", "--batteryState", "charged", "--batteryLevel", "100"])
            for appearance, large_type in [("light", False), ("dark", False), ("light", True), ("dark", True)]:
                variant = appearance + ("-accessibility" if large_type else "")
                folder = device_folder / variant
                folder.mkdir()
                run(["xcrun", "simctl", "ui", udid, "appearance", appearance])
                for scene in SCENES:
                    run(["xcrun", "simctl", "terminate", udid, BUNDLE], check=False)
                    launch = ["xcrun", "simctl", "launch", udid, BUNDLE, "--climate-screenshot", scene]
                    if large_type:
                        launch.append("--climate-large-text")
                    run(launch)
                    time.sleep(2)  # One layout/paint pass; fixtures disable animation and network.
                    path = folder / f"{scene}.png"
                    run(["xcrun", "simctl", "io", udid, "screenshot", str(path)])
                    manifest["captures"].append(str(path.relative_to(out)))
                    print(f"Captured {device['name']} {variant}/{scene}", flush=True)
        manifest["status"] = "captured-awaiting-human-visual-review"
        print(f"Native evidence written to {out}. Inspect every image; capture success is not visual approval.")
    except Exception as error:
        manifest["status"] = "failed"
        manifest["error"] = str(error)
        print(str(error), file=sys.stderr)
        return 1
    finally:
        for udid in udids:
            # Only simulators created by this script are affected; existing devices remain untouched.
            try:
                run(["xcrun", "simctl", "shutdown", udid], check=False)
                run(["xcrun", "simctl", "delete", udid], check=False)
            except Exception as shutdown_error:
                manifest.setdefault("shutdownErrors", []).append(str(shutdown_error))
        (out / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
