#!/usr/bin/env python3

import json
import pathlib
import stat
import subprocess
import tempfile
import unittest
import tarfile

ROOT = pathlib.Path(__file__).resolve().parents[1]


class LifecycleTests(unittest.TestCase):
    def test_manifest_validates_with_installed_omarchy(self):
        completed = subprocess.run(["omarchy", "plugin", "validate", str(ROOT)],
                                   text=True, capture_output=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)

    def test_clean_install_payload_contains_runtime_files(self):
        required = ["manifest.json", "Panel.qml", "Service.qml", "qmldir", "Model.js",
                    "ProtonVpnIcon.qml", "protonvpn-data-helper", "protonvpn-system-helper",
                    "protonvpn-signin-terminal"]
        for name in required:
            self.assertTrue((ROOT / name).is_file(), name)
        manifest = json.loads((ROOT / "manifest.json").read_text())
        self.assertEqual(manifest["id"], "denizkin.protonvpn")
        for helper in ("protonvpn-data-helper", "protonvpn-system-helper", "protonvpn-signin-terminal"):
            self.assertTrue((ROOT / helper).stat().st_mode & stat.S_IXUSR)

    def test_checkout_can_be_copied_updated_and_removed_in_isolation(self):
        with tempfile.TemporaryDirectory() as directory:
            target = pathlib.Path(directory) / "denizkin.protonvpn"
            subprocess.run(["cp", "-a", str(ROOT), str(target)], check=True)
            self.assertTrue((target / "manifest.json").is_file())
            subprocess.run(["omarchy", "plugin", "validate", str(target)], check=True,
                           stdout=subprocess.DEVNULL)
            # Removal owns only the plugin directory; it must not contain Proton account data.
            self.assertFalse(any(path.name in {"settings.json", "connection_persistence.json"}
                                 for path in target.rglob("*")))

    def test_signin_wrapper_holds_failures_for_acknowledgement(self):
        completed = subprocess.run(
            [str(ROOT / "protonvpn-signin-terminal"), str(ROOT / "tests/fake-protonvpn"), "test-user"],
            input="\n", text=True, capture_output=True)
        self.assertEqual(completed.returncode, 4)
        self.assertIn("Proton may be silent for several seconds while verifying", completed.stdout)
        self.assertIn("The window is still working", completed.stdout)
        self.assertIn("press Enter to close", completed.stdout)
        self.assertIn("Authentication failed", completed.stderr)

    def test_release_archive_contains_only_reviewed_paths(self):
        allowed_roots = {
            "LICENSE", "Model.js", "Panel.qml", "ProtonVpnIcon.qml", "Service.qml", "qmldir",
            "manifest.json", "README.md", "CHANGELOG.md", "DISTRIBUTION.md", "preview.png",
            "protonvpn-data-helper", "protonvpn-system-helper", "protonvpn-signin-terminal",
            "assets", "tests", "tools",
        }
        with tempfile.TemporaryDirectory() as directory:
            completed = subprocess.run([str(ROOT / "tools/package.sh"), directory],
                                       text=True, capture_output=True)
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            archive = next(pathlib.Path(directory).glob("*.tar.gz"))
            with tarfile.open(archive, "r:gz") as package:
                names = [name.removeprefix("./") for name in package.getnames()]
            self.assertTrue(names)
            self.assertTrue(all(name.split("/", 1)[0] in allowed_roots for name in names), names)
            forbidden = {".git", "dist", "private", ".agents", ".claude", ".codex", "graphify-out"}
            self.assertFalse(any(part in forbidden or part.startswith(".env")
                                 for name in names for part in pathlib.PurePosixPath(name).parts))


if __name__ == "__main__":
    unittest.main()
