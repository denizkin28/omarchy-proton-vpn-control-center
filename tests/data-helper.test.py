#!/usr/bin/env python3

import importlib.machinery
import importlib.util
import io
import json
import pathlib
import subprocess
import sys
import unittest
from contextlib import redirect_stdout
from types import SimpleNamespace
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parents[1]
HELPER = ROOT / "protonvpn-data-helper"


def load_helper():
    loader = importlib.machinery.SourceFileLoader("protonvpn_data_helper", str(HELPER))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class DataHelperTests(unittest.TestCase):
    def test_installed_proton_package_is_compatible(self):
        if load_helper().package_version("proton-vpn-api-core") is None:
            self.skipTest("Proton VPN API Core is not installed")
        completed = subprocess.run(
            [str(HELPER), "--query", "AE#", "--available-only", "--limit", "2"],
            check=True,
            text=True,
            capture_output=True,
        )
        result = json.loads(completed.stdout)
        self.assertTrue(result["ok"])
        self.assertEqual(result["schemaVersion"], 1)
        self.assertRegex(result["protonPackageVersion"], r"^\d+\.\d+")
        self.assertLessEqual(len(result["servers"]), 2)

    def test_normalizes_without_exposing_proton_objects(self):
        helper = load_helper()
        server = SimpleNamespace(
            name="CH#42", city="Zurich", state="Zurich", exit_country="CH", entry_country="IS",
            latitude=47.37, longitude=8.54, load=17, tier=2, enabled=True,
            under_maintenance=False, features=[1, 4],
        )
        self.assertEqual(helper.normalize(server), {
            "id": "CH#42", "city": "Zurich", "region": "Zurich", "exitCountry": "CH", "entryCountry": "IS",
            "latitude": 47.37, "longitude": 8.54,
            "load": 17, "tier": 2, "tierName": "Plus", "online": True,
            "maintenance": False, "features": ["secure-core", "p2p"],
        })

    def test_incompatible_proton_api_fails_as_versioned_json(self):
        helper = load_helper()
        output = io.StringIO()
        with mock.patch.object(helper, "load_normalized_servers", side_effect=ImportError("changed API")), \
                mock.patch.object(sys, "argv", [str(HELPER)]), redirect_stdout(output):
            self.assertEqual(helper.main(), 2)
        result = json.loads(output.getvalue())
        self.assertFalse(result["ok"])
        self.assertEqual(result["schemaVersion"], 1)
        self.assertEqual(result["servers"], [])
        self.assertIn("ImportError", result["detail"])


if __name__ == "__main__":
    unittest.main()
