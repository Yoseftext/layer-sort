from __future__ import annotations

import contextlib
import importlib.util
import io
import json
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

    def test_thermal_status_three_and_soc_severity_are_warning_only(self) -> None:
        parsed = device_qa.parse_thermal(
            "Thermal Status: 3\n"
            "Cached temperatures:\n"
            "Temperature{mValue=42.0, mType=0, mName=CPU, mStatus=0}\n"
            "Current temperatures from HAL:\n"
            "Temperature{mValue=50.0, mType=8, mName=soc, mStatus=3}\n"
        )
        self.assertEqual(parsed["thermal_status_code"], 3)
        self.assertEqual(parsed["thermal_status_name"], "SEVERE")
        self.assertTrue(parsed["thermal_warning"])
        self.assertEqual(parsed["performance_gate"], "ALLOW")
        self.assertEqual(parsed["performance_gate_sources"]["android_framework_global_severe"], True)
        self.assertEqual(parsed["performance_gate_sources"]["current_hal_non_soc_sensor_severe"], False)
        self.assertEqual(parsed["performance_gate_sources"]["soc_sensor_used"], False)
        self.assertEqual(len(parsed["sensors"]), 2)
        self.assertEqual(parsed["sensors"][0]["source"], "cached")
        self.assertEqual(parsed["sensors"][1]["source"], "hal")
        self.assertEqual(parsed["sensors"][1]["value_c"], 50.0)
        self.assertEqual(parsed["sensors"][1]["status_name"], "UNVERIFIED")
        self.assertEqual(parsed["sensors"][1]["reported_status_name"], "SEVERE")
        self.assertEqual(parsed["sensors"][1]["verification"], "UNVERIFIED")
        self.assertEqual(parsed["soc_verification"], "UNVERIFIED")
        self.assertIn("Thermal Status: 3", parsed["diagnostic_lines"])

    def test_performance_gate_requires_framework_and_non_soc_hal_severity(self) -> None:
        parsed = device_qa.parse_thermal(
            "Thermal Status: 3\n"
            "Current temperatures from HAL:\n"
            "Temperature{mValue=67.0, mType=0, mName=CPU4, mStatus=3}\n"
            "Temperature{mValue=28.0, mType=1, mName=GPU, mStatus=0}\n"
            "Temperature{mValue=50.0, mType=8, mName=soc, mStatus=3}\n"
        )
        self.assertEqual(parsed["current_hal_severe_sensor_count"], 1)
        self.assertEqual(parsed["current_hal_severe_sensor_names"], ["CPU4"])
        self.assertEqual(parsed["performance_gate"], "BLOCK")
        self.assertEqual(parsed["performance_gate_sources"]["soc_sensor_used"], False)

    def test_soc_severity_alone_never_blocks_performance(self) -> None:
        parsed = device_qa.parse_thermal(
            "Thermal Status: 0\n"
            "Current temperatures from HAL:\n"
            "Temperature{mValue=50.0, mType=8, mName=soc, mStatus=3}\n"
        )
        self.assertEqual(parsed["thermal_status_name"], "NONE")
        self.assertEqual(parsed["current_hal_severe_sensor_count"], 0)
        self.assertEqual(parsed["performance_gate"], "ALLOW")
        self.assertTrue(parsed["thermal_warning"])

    def test_stale_cached_sensor_severity_does_not_block_performance(self) -> None:
        parsed = device_qa.parse_thermal(
            "Thermal Status: 0\n"
            "Cached temperatures:\n"
            "Temperature{mValue=67.0, mType=0, mName=CPU, mStatus=3}\n"
            "Current temperatures from HAL:\n"
            "Temperature{mValue=32.0, mType=0, mName=CPU, mStatus=0}\n"
        )
        self.assertEqual(parsed["thermal_status_name"], "NONE")
        self.assertEqual(parsed["cached_severe_sensor_count"], 1)
        self.assertEqual(parsed["current_hal_severe_sensor_count"], 0)
        self.assertEqual(parsed["performance_gate"], "ALLOW")
        self.assertTrue(parsed["thermal_warning"])

    def test_thermal_action_returns_pass_with_severe_warning(self) -> None:
        thermal_output = (
            "Thermal Status: 3\n"
            "Current temperatures from HAL:\n"
            "Temperature{mValue=50.0, mType=8, mName=soc, mStatus=3}\n"
        )
        args = device_qa.build_parser().parse_args(["thermal"])
        output = io.StringIO()
        with (
            patch.object(device_qa, "phone_lock", return_value=contextlib.nullcontext()),
            patch.object(device_qa, "connected_serial", return_value="approved-device"),
            patch.object(device_qa, "validate_device", return_value={"model": "CPH1937"}),
            patch.object(device_qa, "ensure_game_installed"),
            patch.object(device_qa, "shell_text", return_value=thermal_output),
            contextlib.redirect_stdout(output),
        ):
            result = device_qa.execute(args)
        payload = json.loads(output.getvalue())
        self.assertEqual(result, 0)
        self.assertEqual(payload["status"], "PASS")
        self.assertTrue(payload["thermal_warning"])
        self.assertEqual(payload["performance_gate"], "ALLOW")

    def test_performance_check_fails_only_when_two_channels_agree(self) -> None:
        thermal_output = (
            "Thermal Status: 3\n"
            "Current temperatures from HAL:\n"
            "Temperature{mValue=67.0, mType=0, mName=CPU4, mStatus=3}\n"
        )
        args = device_qa.build_parser().parse_args(["performance-check"])
        output = io.StringIO()
        with (
            patch.object(device_qa, "phone_lock", return_value=contextlib.nullcontext()),
            patch.object(device_qa, "connected_serial", return_value="approved-device"),
            patch.object(device_qa, "validate_device", return_value={"model": "CPH1937"}),
            patch.object(device_qa, "ensure_game_installed"),
            patch.object(device_qa, "shell_text", return_value=thermal_output),
            contextlib.redirect_stdout(output),
        ):
            result = device_qa.execute(args)
        payload = json.loads(output.getvalue())
        self.assertEqual(result, 1)
        self.assertEqual(payload["status"], "FAIL")
        self.assertEqual(payload["performance_gate"], "BLOCK")

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

    def test_agentctl_entrypoint_uses_pinned_interpreters(self) -> None:
        agentctl_path = ROOT / "tools" / "device-tests" / "agentctl"
        agentctl_source = agentctl_path.read_text(encoding="utf-8")
        self.assertTrue(agentctl_source.startswith("#!/usr/bin/bash\n"))
        self.assertIn("exec /usr/bin/python3.13 -I ", agentctl_source)
        self.assertNotIn("/usr/bin/env", agentctl_source)

    def test_device_qa_uses_pinned_python_and_adb(self) -> None:
        source = MODULE_PATH.read_text(encoding="utf-8")
        self.assertTrue(source.startswith("#!/usr/bin/python3.13 -I\n"))
        self.assertEqual(
            device_qa.ADB,
            Path("/usr/lib/android-sdk/platform-tools/adb")
        )

    def test_unsafe_commands_are_not_exposed(self) -> None:
        parser = device_qa.build_parser()
        for command in ("phone", "shell", "install", "uninstall", "clear", "pm"):
            with self.subTest(command=command):
                with contextlib.redirect_stderr(io.StringIO()):
                    with self.assertRaises(SystemExit):
                        parser.parse_args([command])


if __name__ == "__main__":
    unittest.main()
