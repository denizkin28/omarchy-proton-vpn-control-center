#!/usr/bin/env python3

import json
import pathlib
import subprocess
import tempfile
import os
import asyncio
import contextlib
import importlib.util
import io
import types
import unittest
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parents[1]
HELPER = ROOT / "protonvpn-system-helper"


def load_helper_module():
    spec = importlib.util.spec_from_file_location("protonvpn_system_helper", HELPER)
    if spec is None or spec.loader is None:
        # Extension-less scripts need an explicit source loader.
        from importlib.machinery import SourceFileLoader
        spec = importlib.util.spec_from_loader("protonvpn_system_helper",
                                               SourceFileLoader("protonvpn_system_helper", str(HELPER)))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def call(*arguments, check=True, env=None):
    completed = subprocess.run([str(HELPER), *arguments], text=True, capture_output=True, check=check,
                               env=env)
    return completed, json.loads(completed.stdout)


class SystemHelperTests(unittest.TestCase):
    def _rollback_fixture(self, fail_advanced=False):
        saved = types.SimpleNamespace(
            protocol="wireguard",
            killswitch=1,
            features=types.SimpleNamespace(
                split_tunneling=types.SimpleNamespace(enabled=False)))

        class Persistence:
            def __init__(self): self.saved_states = []
            def get(self, user_tier): return saved
            def save(self, settings): self.saved_states.append(int(settings.killswitch))

        class Backend:
            async def disable(self): pass
            async def disable_ipv6_leak_protection(self): pass
            async def enable(self, permanent=False):
                if fail_advanced: raise RuntimeError("backend unavailable")

        class KillSwitch:
            @staticmethod
            def get(protocol): return Backend

        class SplitTunneling:
            @staticmethod
            async def get(uid): return None

        settings_module = types.ModuleType("proton.vpn.core.settings")
        settings_module.SplitTunnelingConfig = lambda **values: values
        settings_module.SplitTunnelingMode = lambda value: value
        killswitch_module = types.ModuleType("proton.vpn.killswitch.interface")
        killswitch_module.KillSwitch = KillSwitch
        split_module = types.ModuleType("proton.vpn.split_tunneling")
        split_module.SplitTunneling = SplitTunneling
        modules = {
            "proton.vpn.core.settings": settings_module,
            "proton.vpn.killswitch.interface": killswitch_module,
            "proton.vpn.split_tunneling": split_module,
        }
        return Persistence(), saved, modules

    def test_advanced_kill_switch_rollback_persists_only_after_backend_restore(self):
        helper = load_helper_module()
        persistence, saved, modules = self._rollback_fixture()
        snapshot = {"userTier": 2, "protocol": "openvpn-udp", "killSwitch": 2, "splitEnabled": False,
                    "splitMode": "exclude", "splitExclude": {}, "splitInclude": {}}
        with mock.patch.dict("sys.modules", modules):
            error = asyncio.run(helper.restore_transaction_snapshot(persistence, snapshot))
        self.assertEqual(error, "")
        self.assertEqual(persistence.saved_states, [0, 2])
        self.assertEqual(saved.killswitch, 2)

    def test_failed_advanced_backend_restore_leaves_persisted_state_off(self):
        helper = load_helper_module()
        persistence, saved, modules = self._rollback_fixture(fail_advanced=True)
        snapshot = {"userTier": 2, "protocol": "wireguard", "killSwitch": 2, "splitEnabled": False,
                    "splitMode": "exclude", "splitExclude": {}, "splitInclude": {}}
        with mock.patch.dict("sys.modules", modules):
            error = asyncio.run(helper.restore_transaction_snapshot(persistence, snapshot))
        self.assertIn("advanced kill switch backend restore failed", error)
        self.assertEqual(persistence.saved_states, [0])
        self.assertEqual(saved.killswitch, 0)

    def test_reconnect_failure_rolls_back_then_restores_the_previous_server(self):
        helper = load_helper_module()
        split = types.SimpleNamespace(
            enabled=False,
            mode=types.SimpleNamespace(value="exclude"),
            exclude=types.SimpleNamespace(to_dict=lambda: {}),
            include=types.SimpleNamespace(to_dict=lambda: {}),
        )
        saved = types.SimpleNamespace(protocol="wireguard", killswitch=1,
                                      features=types.SimpleNamespace(split_tunneling=split))

        class Persistence:
            def get(self, user_tier): return saved

        persistence = Persistence()
        settings_module = types.ModuleType("proton.vpn.core.settings")
        settings_module.SettingsPersistence = lambda: persistence
        connect_attempts = 0

        def fake_run(command, timeout=10):
            nonlocal connect_attempts
            if command[1] == "connect":
                connect_attempts += 1
                code = 2 if connect_attempts == 1 else 0
                return subprocess.CompletedProcess(command, code, "", "Reconnect failed" if code else "")
            return subprocess.CompletedProcess(command, 0, "", "")

        async def apply_setting(args):
            print('{"ok":true}')
            return 0

        args = types.SimpleNamespace(
            cli="fake-protonvpn", operation="settings", setting="protocol", value="wireguard",
            enabled="off", mode="exclude", apps="[]", ips="[]", dry_run=False)
        output = io.StringIO()
        with mock.patch.dict("sys.modules", {"proton.vpn.core.settings": settings_module}), \
             mock.patch.object(helper, "connection_state", return_value={"connected": True, "server": "AE#44"}), \
             mock.patch.object(helper, "resolve_user_tier", return_value=2), \
             mock.patch.object(helper, "mark_intentional_disconnect"), \
             mock.patch.object(helper, "settings_set", side_effect=apply_setting), \
             mock.patch.object(helper, "restore_transaction_snapshot", return_value=""), \
             mock.patch.object(helper, "run", side_effect=fake_run), \
             contextlib.redirect_stdout(output):
            code = asyncio.run(helper.transaction_set(args))
        result = json.loads(output.getvalue())
        self.assertNotEqual(code, 0)
        self.assertTrue(result["rolledBack"])
        self.assertTrue(result["reconnected"])
        self.assertEqual(result["steps"], ["disconnected", "setting-applied", "rolled-back",
                                           "reconnected-after-rollback"])
        self.assertEqual(connect_attempts, 2)

    def test_health_is_normalized_json(self):
        _, result = call("health")
        self.assertEqual(result["schemaVersion"], 1)
        self.assertIsInstance(result["health"]["rxBytes"], int)
        self.assertIn("routeThroughVpn", result["health"])

    def test_network_is_read_only_and_normalized(self):
        _, result = call("network")
        self.assertIn("connection", result["network"])
        self.assertIn("online", result["network"])

    def test_account_state_uses_an_atomic_exit_code(self):
        completed, result = call("account", "--cli", str(ROOT / "tests/fake-protonvpn"), check=False)
        self.assertEqual(completed.returncode, 0)
        self.assertTrue(result["account"]["signedIn"])
        environment = dict(os.environ, PROTONVPN_FAKE_SIGNED_OUT="1")
        completed, result = call("account", "--cli", str(ROOT / "tests/fake-protonvpn"),
                                 check=False, env=environment)
        self.assertEqual(completed.returncode, 3)
        self.assertFalse(result["account"]["signedIn"])
        environment = dict(os.environ, PROTONVPN_FAKE_STALE_SESSION="1")
        completed, result = call("account", "--cli", str(ROOT / "tests/fake-protonvpn"),
                                 check=False, env=environment)
        self.assertEqual(completed.returncode, 4)
        self.assertTrue(result["account"]["identityPresent"])
        self.assertFalse(result["account"]["sessionValid"])

    def test_account_plan_selects_the_matching_settings_tier(self):
        helper = load_helper_module()
        fake = str(ROOT / "tests/fake-protonvpn")
        with mock.patch.dict(os.environ, {"PROTONVPN_FAKE_PLAN": "Free"}):
            self.assertEqual(helper.resolve_user_tier(fake), 0)
        with mock.patch.dict(os.environ, {"PROTONVPN_FAKE_PLAN": "Plus"}):
            self.assertEqual(helper.resolve_user_tier(fake), 2)
        with mock.patch.dict(os.environ, {"PROTONVPN_FAKE_PLAN": "Visionary"}):
            self.assertEqual(helper.resolve_user_tier(fake), 3)

    def test_installed_split_tunnelling_api_is_compatible(self):
        _, result = call("split-get")
        self.assertTrue(result["splitTunneling"]["available"])
        self.assertIn(result["splitTunneling"]["mode"], ("include", "exclude"))

    def test_port_status_does_not_start_the_service(self):
        _, before = call("port-status")
        _, after = call("port-status")
        self.assertEqual(before["portForward"]["active"], after["portForward"]["active"])
        self.assertIn("requirements", after["portForward"])
        self.assertIn("natPmpInstalled", after["portForward"])

    def test_port_status_uses_the_configured_cli(self):
        _, result = call("port-status", "--cli", str(ROOT / "tests/fake-protonvpn"))
        self.assertTrue(result["portForward"]["connected"])

    def test_profile_rejects_unknown_settings_before_running_commands(self):
        completed, result = call("profile-apply", "--profile", '{"settings":{"unsupported":"on"}}', check=False)
        self.assertNotEqual(completed.returncode, 0)
        self.assertFalse(result["ok"])

    def test_profile_runs_only_validated_cli_commands(self):
        profile = json.dumps({
            "mode": "Server", "target": "CH#42", "feature": "P2P",
            "settings": {"netshield": "off", "vpn-accelerator": "on"},
        })
        with tempfile.TemporaryDirectory() as state:
            environment = dict(os.environ, XDG_STATE_HOME=state)
            _, result = call("profile-apply", "--cli", str(ROOT / "tests/fake-protonvpn"),
                             "--profile", profile, env=environment)
            self.assertTrue(result["ok"])
            self.assertEqual(result["results"][-1]["command"], ["connect", "CH#42"])
            marker = pathlib.Path(state) / "protonvpn-intentional-disconnect"
            self.assertTrue(marker.is_file(), "profile disconnect must suppress recovery in every widget")

    def test_profile_failure_restores_the_previous_server(self):
        profile = json.dumps({
            "mode": "Fastest", "target": "", "feature": "None",
            "settings": {"netshield": "off"},
        })
        with tempfile.TemporaryDirectory() as state:
            log = pathlib.Path(state) / "commands.log"
            environment = dict(os.environ, XDG_STATE_HOME=state,
                               PROTONVPN_FAKE_LOG=str(log), PROTONVPN_FAKE_FAIL_SETTING="netshield")
            completed, result = call("profile-apply", "--cli", str(ROOT / "tests/fake-protonvpn"),
                                     "--profile", profile, env=environment, check=False)
            self.assertNotEqual(completed.returncode, 0)
            self.assertTrue(result["reconnected"])
            commands = log.read_text().splitlines()
            self.assertIn("disconnect", commands)
            self.assertIn("connect AE#44", commands)

    def test_lists_installed_apps_as_normalized_json(self):
        _, result = call("apps")
        self.assertIsInstance(result["applications"], list)
        if result["applications"]:
            self.assertEqual(set(result["applications"][0]), {"name", "executable", "icon"})

    def test_exposes_only_protocols_validated_by_proton(self):
        _, result = call("settings-get")
        protocols = result["coreSettings"]["protocols"]
        self.assertTrue(protocols)
        self.assertIn(result["coreSettings"]["protocol"], [item["value"] for item in protocols])
        self.assertNotIn("stealth", [item["value"] for item in protocols])

    def test_recovery_and_manual_disconnect_share_a_safety_marker(self):
        with tempfile.TemporaryDirectory() as state:
            environment = dict(os.environ, XDG_STATE_HOME=state)
            fake = str(ROOT / "tests/fake-protonvpn")
            _, disconnected = call("disconnect", "--cli", fake, env=environment)
            self.assertTrue(disconnected["disconnected"])
            completed, recovery = call("recover", "--cli", fake, "--server", "CH#42",
                                       env=environment, check=False)
            self.assertNotEqual(completed.returncode, 0)
            self.assertTrue(recovery["skipped"])
            self.assertEqual(recovery["error"], "Manual disconnect respected")

    def test_diagnostics_are_local_redacted_and_private(self):
        with tempfile.TemporaryDirectory() as state:
            environment = dict(os.environ, XDG_STATE_HOME=state)
            _, result = call("diagnostics", "--cli", str(ROOT / "tests/fake-protonvpn"), env=environment)
            path = pathlib.Path(result["diagnostics"]["path"])
            self.assertTrue(path.is_file())
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertNotIn("integration-test@invalid", path.read_text())

    def test_transaction_rejects_incomplete_requests_before_mutation(self):
        completed, result = call("transaction-set", "--operation", "settings", check=False)
        self.assertNotEqual(completed.returncode, 0)
        self.assertEqual(result["error"], "A setting and value are required")

    def test_transaction_dry_run_is_non_mutating_and_has_rollback(self):
        _, result = call("transaction-set", "--operation", "settings", "--setting", "protocol",
                         "--value", "wireguard", "--dry-run")
        self.assertTrue(result["dryRun"])
        self.assertTrue(result["transaction"]["rollbackAvailable"])


if __name__ == "__main__":
    unittest.main()
