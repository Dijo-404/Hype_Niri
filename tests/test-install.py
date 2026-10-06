#!/usr/bin/env python3
"""Installer regression checks: python3 tests/test-install.py.

Runs sourced installer functions with mocked privileged commands. A temporary
source copy redirects home paths without changing the real HOME environment.
"""

import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="hype-niri-install-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.user_home = self.root / "home"
        self.user_home.mkdir()
        self.log = self.root / "commands"
        self.source = self.root / "install.sh"
        self.source.write_text(
            (REPO / "install.sh").read_text().replace("$HOME", "$INSTALL_TEST_HOME")
        )

    def run_installer(self, code, *, input_text="", succeeds=True):
        environment = os.environ.copy()
        environment.update(
            INSTALL_TEST_HOME=str(self.user_home),
            INSTALL_TEST_LOG=str(self.log),
        )
        preamble = f"""
source {shlex.quote(str(self.source))}
SCRIPT_DIR={shlex.quote(str(REPO))}
print_header() {{ :; }}
print_step() {{ :; }}
print_warn() {{ :; }}
print_done() {{ :; }}
confirm() {{ return 0; }}
sleep() {{ :; }}
curl() {{ return 99; }}
sudo() {{ printf '%s\\n' "$*" >> "$INSTALL_TEST_LOG"; return 1; }}
systemctl() {{ return 1; }}
stdbuf() {{ shift 2; "$@"; }}
"""
        result = subprocess.run(
            ["bash", "-c", preamble + code],
            input=input_text,
            capture_output=True,
            text=True,
            env=environment,
            timeout=30,
        )
        if succeeds:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def commands(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def validation_fixture(self):
        """Provide valid files while varying only the service state under test."""
        source = self.source.read_text()
        critical = re.search(r"local critical_files=\((.*?)\n    \)", source, re.S)
        self.assertIsNotNone(critical)
        for path in re.findall(r'"([^"]+)"', critical.group(1)):
            fixture = Path(path.replace("$INSTALL_TEST_HOME", str(self.user_home)))
            self.assertTrue(fixture.is_relative_to(self.user_home))
            fixture.parent.mkdir(parents=True, exist_ok=True)
            fixture.write_text("")
            fixture.chmod(0o755)

        agent = self.root / "polkit-agent"
        agent.touch()
        agent.chmod(0o755)
        policy = self.root / "installed-oom-policy"
        policy.write_text((REPO / "systemd/user@.service.d/60-hype-niri-oomd.conf").read_text())
        self.source.write_text(
            source.replace("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1", str(agent))
            .replace("/etc/systemd/system/user@.service.d/60-hype-niri-oomd.conf", str(policy))
        )
        return r"""
command() {
    [[ $1 == -v ]] && return 0
    builtin command "$@"
}
niri() { [[ $1 == validate ]]; }
fc-match() { printf '%s\n' "$3"; }
systemctl() {
    printf 'systemctl %s\n' "$*" >> "$INSTALL_TEST_LOG"
    case "$*" in
        '--user show-environment') return 1 ;;
        'is-active --quiet user@'*) [[ ${ACTIVE_MANAGER:-0} == 1 ]] ;;
        'list-unit-files NetworkManager.service --no-legend')
            [[ ${MISSING_NETWORK:-0} == 1 ]] || printf 'NetworkManager.service enabled\n'
            ;;
        'list-unit-files '*) printf 'available.service enabled\n' ;;
        'is-enabled --quiet '*|'is-active --quiet '*) return 0 ;;
        'show user@'*)
            printf '%s\n' MemoryAccounting=yes ManagedOOMMemoryPressure=kill ManagedOOMSwap=kill \
                "ManagedOOMMemoryPressureLimit=${PRESSURE_LIMIT:-1717986918}" \
                "ManagedOOMMemoryPressureDurationUSec=${PRESSURE_DURATION:-10s}"
            ;;
        *) printf 'Unexpected systemctl call: %s\n' "$*" >&2; return 99 ;;
    esac
}
"""

    def test_validation_succeeds_before_user_manager_starts(self):
        self.run_installer(self.validation_fixture() + "validate")
        self.assertFalse(any(command.startswith("systemctl show user@") for command in self.commands()))

    def test_validation_rejects_missing_required_network_service(self):
        result = self.run_installer(
            self.validation_fixture() + "MISSING_NETWORK=1 validate", succeeds=False
        )
        self.assertIn("Required system service unit unavailable: NetworkManager.service", result.stdout)

    def test_validation_accepts_effective_oom_policy(self):
        self.run_installer(self.validation_fixture() + "ACTIVE_MANAGER=1 validate")

    def test_validation_rejects_pressure_limit_override(self):
        result = self.run_installer(
            self.validation_fixture() + "ACTIVE_MANAGER=1 PRESSURE_LIMIT=3221225471 validate",
            succeeds=False,
        )
        self.assertIn("required 40% for 10 seconds", result.stdout)

    def test_validation_rejects_pressure_duration_override(self):
        result = self.run_installer(
            self.validation_fixture() + "ACTIVE_MANAGER=1 PRESSURE_DURATION=30s validate",
            succeeds=False,
        )
        self.assertIn("required 40% for 10 seconds", result.stdout)

    def test_backups_include_generated_settings_and_preserve_symlinks(self):
        settings = self.user_home / ".config/gtk-3.0/settings.ini"
        settings.parent.mkdir(parents=True)
        settings.write_text("custom settings\n")
        (self.user_home / ".zshrc").symlink_to("missing-zsh-target")
        result = self.run_installer('backup_configs; printf "%s\\n" "$BACKUP_DIR"')
        backup = Path(result.stdout.strip())
        self.assertEqual((backup / ".config/gtk-3.0/settings.ini").read_text(), "custom settings\n")
        self.assertTrue((backup / ".zshrc").is_symlink())
        self.assertEqual(os.readlink(backup / ".zshrc"), "missing-zsh-target")

    def test_declined_backup_stops_before_overwrite(self):
        settings = self.user_home / ".zshrc"
        settings.write_text("keep me")
        self.run_installer("confirm() { return 1; }; backup_configs", succeeds=False)
        self.assertEqual(settings.read_text(), "keep me")

    def test_failed_directory_publish_restores_previous_config(self):
        destination = self.user_home / ".config/niri"
        destination.mkdir(parents=True)
        (destination / "config.kdl").write_text("previous config")
        staged = self.root / "staged"
        staged.mkdir()
        (staged / "config.kdl").write_text("new config")
        self.run_installer(f"""
mv() {{
    if [[ $* == *'.previous'* || "${{!#}}" != {shlex.quote(str(destination))} ]]; then
        command mv "$@"
    else
        return 1
    fi
}}
replace_directory {shlex.quote(str(staged))} {shlex.quote(str(destination))}
""", succeeds=False)
        self.assertEqual((destination / "config.kdl").read_text(), "previous config")

    def test_mirror_refresh_does_not_sync_databases_without_upgrade(self):
        self.run_installer("""
reflector() { printf 'Server = https://example.invalid/mirror\n' > "${!#}"; }
sudo() { printf '%s\n' "$*" >> "$INSTALL_TEST_LOG"; return 0; }
refresh_mirrors
""")
        self.assertFalse(any(command.startswith("pacman ") for command in self.commands()))

    def test_declined_upgrade_does_not_refresh_package_databases(self):
        self.run_installer(
            "confirm() { return 1; }; update_system_packages", succeeds=False
        )
        self.assertEqual(self.commands(), [])

    def test_package_list_ignores_indented_comments_and_duplicates(self):
        fixture = self.root / "packages"
        fixture.mkdir()
        (fixture / "pkglist.txt").write_text("  # comment\n\n niri # desktop\nniri\n waybar\n")
        self.run_installer(f"""
SCRIPT_DIR={shlex.quote(str(fixture))}
pacman() {{ return 0; }}
sudo() {{ printf '%s\\n' "$*" >> "$INSTALL_TEST_LOG"; return 0; }}
install_packages
""")
        self.assertEqual(self.commands(), ["pacman -S --needed --noconfirm niri waybar"])

    def test_wallpaper_selection_handles_large_collection_and_preserves_files(self):
        fixture = self.root / "configs"
        for directory in ("niri", "waybar", "scripts", "alacritty", "fuzzel", "mako", "fastfetch", "wlogout", "hypr", "Wallpapers"):
            (fixture / directory).mkdir(parents=True)
        (fixture / "scripts/dummy.sh").write_text("#!/bin/bash\nexit 0\n")
        (fixture / "Wallpapers/00000 wallpaper.jpg").write_text("repository wallpaper")
        wallpapers = self.user_home / "Pictures/Wallpapers"
        wallpapers.mkdir(parents=True)
        for index in range(5000):
            (wallpapers / f"{index:05d} wallpaper.jpg").touch()
        first = wallpapers / "00000 wallpaper.jpg"
        first.write_text("user wallpaper")
        self.run_installer(f"SCRIPT_DIR={shlex.quote(str(fixture))}; copy_configs")
        self.assertEqual(first.read_text(), "user wallpaper")
        self.assertEqual((self.user_home / ".local/state/niri/current_wallpaper").resolve(), first)
        self.assertTrue((self.user_home / ".config/niri/outputs.kdl").exists())

    def test_generated_theme_does_not_modify_symlink_targets(self):
        original = self.root / "original-theme"
        original.mkdir()
        (original / "settings.ini").write_text("original settings")
        (self.user_home / ".config").mkdir()
        (self.user_home / ".config/gtk-3.0").symlink_to(original)
        self.run_installer("papirus-folders() { return 0; }; dconf() { return 0; }; setup_gtk")
        self.assertEqual((original / "settings.ini").read_text(), "original settings")
        self.assertFalse((self.user_home / ".config/gtk-3.0").is_symlink())
        self.assertIn("Adwaita-dark", (self.user_home / ".config/gtk-3.0/settings.ini").read_text())

    def test_firewall_setup_retains_existing_rules(self):
        self.run_installer("""
ufw() { :; }
sudo() { printf '%s\n' "$*" >> "$INSTALL_TEST_LOG"; return 0; }
setup_firewall
""")
        self.assertFalse(any("reset" in command for command in self.commands()))
        self.assertIn("ufw --force enable", self.commands())

    def test_warp_mode_failure_prevents_connection(self):
        self.run_installer("""
systemctl() { return 0; }
sudo() { printf '%s\n' "$*" >> "$INSTALL_TEST_LOG"; return 0; }
warp-cli() {
    printf 'warp-cli %s\n' "$*" >> "$INSTALL_TEST_LOG"
    [[ $* != '--accept-tos mode doh' ]]
}
setup_cloudflare
""", input_text="1\n", succeeds=False)
        self.assertNotIn("warp-cli --accept-tos connect", self.commands())
        self.assertTrue(any("enable --now warp-svc" in command for command in self.commands()))

    def test_warp_skip_keeps_current_connection(self):
        self.run_installer("""
systemctl() { return 0; }
sudo() { printf '%s\n' "$*" >> "$INSTALL_TEST_LOG"; return 0; }
warp-cli() { printf 'warp-cli %s\n' "$*" >> "$INSTALL_TEST_LOG"; return 0; }
setup_cloudflare
""", input_text="3\n")
        self.assertFalse(any(command.endswith((" connect", " disconnect")) for command in self.commands()))

    def test_warp_registers_when_status_succeeds_but_registration_is_missing(self):
        self.run_installer("""
sudo() { printf '%s\n' "$*" >> "$INSTALL_TEST_LOG"; return 0; }
warp-cli() {
    printf 'warp-cli %s\n' "$*" >> "$INSTALL_TEST_LOG"
    [[ $* != '--accept-tos registration show' ]]
}
setup_cloudflare
""", input_text="1\n")
        commands = self.commands()
        self.assertIn("warp-cli --accept-tos registration new", commands)
        self.assertLess(
            commands.index("warp-cli --accept-tos registration new"),
            commands.index("warp-cli --accept-tos connect"),
        )

    def test_warp_retains_existing_registration(self):
        self.run_installer("""
sudo() { printf '%s\n' "$*" >> "$INSTALL_TEST_LOG"; return 0; }
warp-cli() { printf 'warp-cli %s\n' "$*" >> "$INSTALL_TEST_LOG"; return 0; }
setup_cloudflare
""", input_text="1\n")
        self.assertIn("warp-cli --accept-tos registration show", self.commands())
        self.assertNotIn("warp-cli --accept-tos registration new", self.commands())

    def test_failed_required_service_propagates_failure(self):
        self.run_installer("""
systemctl() { printf 'NetworkManager.service disabled\n'; }
enable_system_service_now NetworkManager.service
""", succeeds=False)

    def test_stealth_stages_only_runtime_payload_and_replaces_stale_files(self):
        destination = self.user_home / ".local/share/stealth"
        destination.mkdir(parents=True)
        (destination / "stale-test.sh").write_text("stale")
        self.run_installer("""
sudo() { printf '%s\n' "$*" >> "$INSTALL_TEST_LOG"; return 0; }
setup_stealth
""")
        self.assertEqual(
            {entry.name for entry in destination.iterdir()},
            {"stealth.zsh", "install-stealth.sh", "stealth.sh", "stealth.service", "stealth.nft", "stealth.sudoers", "torrc.conf"},
        )

    def test_failed_stealth_install_retains_previous_staging(self):
        destination = self.user_home / ".local/share/stealth"
        destination.mkdir(parents=True)
        (destination / "existing").write_text("keep me")
        self.run_installer("""
sudo() { [[ $1 != bash ]]; }
setup_stealth
""", succeeds=False)
        self.assertEqual((destination / "existing").read_text(), "keep me")

    def test_main_stops_at_failed_phase(self):
        result = self.run_installer("""
preflight() { return 1; }
refresh_mirrors() { printf 'unexpected phase\n'; }
main
""", succeeds=False)
        self.assertEqual(self.commands(), [])
        self.assertNotIn("unexpected phase", result.stdout)

    def test_help_and_invalid_arguments_do_not_start_installation(self):
        self.run_installer("main --help")
        self.run_installer("main --unknown", succeeds=False)
        self.assertEqual(self.commands(), [])

    def test_ly_enable_failure_preserves_previous_display_manager(self):
        self.run_installer("""
systemctl() { printf 'ly@.service disabled\nsddm.service enabled\n'; }
sudo() {
    printf '%s\n' "$*" >> "$INSTALL_TEST_LOG"
    [[ $* != 'systemctl enable --force ly@tty2.service' ]]
}
setup_system
""", succeeds=False)
        self.assertIn("systemctl enable --force ly@tty2.service", self.commands())
        self.assertFalse(any("systemctl disable" in command for command in self.commands()))

    def test_ly_template_is_enabled_before_previous_manager_is_disabled(self):
        self.run_installer("""
systemctl() {
    case "$*" in
        'list-unit-files --type=service --no-legend') printf 'ly@.service disabled\nsddm.service enabled\n' ;;
        'list-unit-files '*) printf '%s enabled\n' "$2" ;;
        '--user show-environment') return 1 ;;
        *) return 0 ;;
    esac
}
sudo() { printf '%s\n' "$*" >> "$INSTALL_TEST_LOG"; return 0; }
bash() { return 0; }
setup_system
""")
        commands = self.commands()
        self.assertLess(
            commands.index("systemctl enable --force ly@tty2.service"),
            commands.index("systemctl disable sddm.service"),
        )
        self.assertIn("systemctl disable getty@tty2.service", commands)
        self.assertFalse(any("start ly" in command for command in commands))


if __name__ == "__main__":
    unittest.main(verbosity=2)
