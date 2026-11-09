from __future__ import annotations

import contextlib
import importlib.util
import io
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "device-tests" / "device_qa.py"
SPEC = importlib.util.spec_from_file_location("layer_sort_device_qa", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
device_qa = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = device_qa
SPEC.loader.exec_module(device_qa)


class DeviceQaParsingTests(unittest.TestCase):
    def test_device_discovery_ignores_offline_entries(self) -> None:
        parsed = device_qa.parse_connected_serials(
            "List of devices attached\n"
            "offline-1 offline product:unknown\n"
            "device-alias device product:CPH1937 model:CPH1937\n"
        )
        self.assertEqual(parsed, ["device-alias"])

    def test_device_selection_uses_approved_identity_not_online_count(self) -> None:
        approved = {
            "ro.product.manufacturer": "OPPO",
            "ro.product.model": "CPH1937",
            "ro.product.device": "OP4B80L1",
            "ro.build.version.release": "11",
            "ro.build.version.sdk": "30",
        }
        emulator = {
            "ro.product.manufacturer": "Google",
            "ro.product.model": "sdk_gphone64_x86_64",
            "ro.product.device": "emu64xa",
            "ro.build.version.release": "16",
            "ro.build.version.sdk": "36",
        }

        def fake_adb(serial, arguments, **kwargs):
            if serial is None:
                return (
                    "List of devices attached\n"
                    "emulator-5554 device product:emu64xa\n"
                    "approved-serial device product:OP4B80L1\n"
                )
            if arguments[:2] == ["shell", "getprop"]:
                return {"emulator-5554": emulator, "approved-serial": approved}[serial][arguments[-1]]
            if arguments == ["shell", "pm", "path", device_qa.PACKAGE_ID]:
                return "package:/data/app/layersort/base.apk" if serial == "approved-serial" else ""
            raise AssertionError(f"Unexpected ADB call: {arguments}")

        with patch.object(device_qa, "adb_call", side_effect=fake_adb):
            self.assertEqual(device_qa.connected_serial(), "approved-serial")

    def test_emulator_serial_is_never_selected_even_with_matching_properties(self) -> None:
        approved = {
            "ro.product.manufacturer": "OPPO",
            "ro.product.model": "CPH1937",
            "ro.product.device": "OP4B80L1",
            "ro.build.version.release": "11",
            "ro.build.version.sdk": "30",
        }

        def fake_adb(serial, arguments, **kwargs):
            if serial is None:
                return (
                    "List of devices attached\n"
                    "emulator-5554 device\n"
                    "physical-oppo device\n"
                )
            if arguments[:2] == ["shell", "getprop"]:
                return approved[arguments[-1]]
            if arguments == ["shell", "pm", "path", device_qa.PACKAGE_ID]:
                return "package:/data/app/layersort/base.apk"
            raise AssertionError(f"Unexpected ADB call: {arguments}")

        with patch.object(device_qa, "adb_call", side_effect=fake_adb):
            self.assertEqual(device_qa.connected_serial(), "physical-oppo")

    def test_device_selection_rejects_multiple_approved_targets(self) -> None:
        approved = {
            "ro.product.manufacturer": "OPPO",
            "ro.product.model": "CPH1937",
            "ro.product.device": "OP4B80L1",
            "ro.build.version.release": "11",
            "ro.build.version.sdk": "30",
        }

        def fake_adb(serial, arguments, **kwargs):
            if serial is None:
                return (
                    "List of devices attached\n"
                    "approved-1 device\n"
                    "approved-2 device\n"
                )
            if arguments[:2] == ["shell", "getprop"]:
                return approved[arguments[-1]]
            if arguments == ["shell", "pm", "path", device_qa.PACKAGE_ID]:
                return "package:/data/app/layersort/base.apk"
            raise AssertionError(f"Unexpected ADB call: {arguments}")

        with patch.object(device_qa, "adb_call", side_effect=fake_adb):
            with self.assertRaises(device_qa.DeviceQaUnknown):
                device_qa.connected_serial()

    def test_screen_size_prefers_override(self) -> None:
        self.assertEqual(
            device_qa.parse_screen_size(
                "Physical size: 1080x2400\nOverride size: 720x1600\n"
            ),
            (720, 1600),
        )

    def test_focus_parser_requires_window_focus_evidence(self) -> None:
        self.assertEqual(
            device_qa.parse_focused_package(
                "mCurrentFocus=Window{abc u0 com.yoseftext.layersort.dev/org.example.Game}"
            ),
            "com.yoseftext.layersort.dev",
        )
        self.assertIsNone(device_qa.parse_focused_package("no focus data"))

    def test_touch_coordinates_are_bounded(self) -> None:
        device_qa.validate_coordinates("tap", (719, 1599), 720, 1600)
        with self.assertRaises(device_qa.DeviceQaFailure):
            device_qa.validate_coordinates("tap", (720, 1599), 720, 1600)
        with self.assertRaises(device_qa.DeviceQaFailure):
            device_qa.validate_coordinates("swipe", (0, 0, 10, 10), 720, 1600, 10)

    def test_battery_temperature_is_converted_from_tenths(self) -> None:
        parsed = device_qa.parse_battery(
            "Current Battery Service state:\n  level: 88\n  status: 2\n  temperature: 296\n"
        )
        self.assertEqual(parsed["battery_level_percent"], 88)
        self.assertEqual(parsed["battery_temperature_c"], 29.6)

    def test_thermal_status_three_is_severe_and_not_ready(self) -> None:
        parsed = device_qa.parse_thermal(
            "Thermal Status: 3\n"
            "Cached temperatures:\n"
            "Temperature{mValue=42.0, mType=0, mName=CPU, mStatus=0}\n"
            "Current temperatures from HAL:\n"
            "Temperature{mValue=25.0, mType=8, mName=soc, mStatus=3}\n"
        )
        self.assertEqual(parsed["thermal_status_code"], 3)
        self.assertEqual(parsed["thermal_status_name"], "SEVERE")
        self.assertEqual(parsed["readiness"], "FAIL")
        self.assertEqual(len(parsed["sensors"]), 2)
        self.assertEqual(parsed["sensors"][0]["source"], "cached")
        self.assertEqual(parsed["sensors"][1]["source"], "hal")
        self.assertEqual(parsed["sensors"][1]["value_c"], 25.0)
        self.assertEqual(parsed["sensors"][1]["status_name"], "SEVERE")
        self.assertIn("Thermal Status: 3", parsed["diagnostic_lines"])

    def test_sensor_severity_is_not_hidden_by_global_status(self) -> None:
        parsed = device_qa.parse_thermal(
            "Thermal Status: 0\n"
            "Current temperatures from HAL:\n"
            "Temperature{mValue=25.0, mType=8, mName=soc, mStatus=3}\n"
        )
        self.assertEqual(parsed["thermal_status_name"], "NONE")
        self.assertEqual(parsed["readiness"], "FAIL")

    def test_missing_thermal_status_is_unknown(self) -> None:
        with self.assertRaises(device_qa.DeviceQaUnknown):
            device_qa.parse_thermal("Thermal service unavailable")

    def test_adb_invocation_uses_argument_vector_not_shell(self) -> None:
        completed = subprocess.CompletedProcess(
            args=["adb"], returncode=0, stdout=b"CPH1937", stderr=b""
        )
        with patch.object(device_qa.subprocess, "run", return_value=completed) as run:
            result = device_qa.adb_call(
                "device-alias", ["shell", "getprop", "ro.product.model"]
            )
        self.assertEqual(result, "CPH1937")
        self.assertIsInstance(run.call_args.args[0], list)
        self.assertNotIn("shell", run.call_args.kwargs)

    def test_mutation_without_owner_approval_is_skipped(self) -> None:
        args = device_qa.build_parser().parse_args(["tap", "20", "30"])
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            result = device_qa.require_approval(args, "tap")
        self.assertEqual(result, "SKIP")
        self.assertIn('"status": "SKIP"', output.getvalue())

    def test_dry_run_needs_no_owner_approval(self) -> None:
        args = device_qa.build_parser().parse_args(
            ["tap", "20", "30", "--dry-run"]
        )
        self.assertIsNone(device_qa.require_approval(args, "tap"))

    def test_invalid_approval_id_fails_closed(self) -> None:
        args = device_qa.build_parser().parse_args(
            ["tap", "20", "30", "--owner-approved", "--approval-id", "bad"]
        )
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            result = device_qa.require_approval(args, "tap")
        self.assertEqual(result, "FAIL")
        self.assertIn('"status": "FAIL"', output.getvalue())

    def test_unsafe_commands_are_not_exposed(self) -> None:
        parser = device_qa.build_parser()
        for command in ("phone", "shell", "install", "uninstall", "clear", "pm"):
            with self.subTest(command=command):
                with contextlib.redirect_stderr(io.StringIO()):
                    with self.assertRaises(SystemExit):
                        parser.parse_args([command])


if __name__ == "__main__":
    unittest.main()
