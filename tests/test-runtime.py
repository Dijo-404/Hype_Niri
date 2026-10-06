#!/usr/bin/env python3
"""Run isolated runtime regressions with mocked desktop commands."""

import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import tempfile
import time
import unittest
from concurrent.futures import ThreadPoolExecutor


REPO = Path(__file__).resolve().parents[1]


class RuntimeTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="hype-niri-runtime-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.user_home = self.root / "home"
        self.scripts = self.user_home / ".config/scripts"
        self.scripts.mkdir(parents=True)
        for source in (REPO / "scripts").glob("*.sh"):
            (self.scripts / source.name).write_text(
                source.read_text().replace("$HOME", "$RUNTIME_TEST_HOME")
            )
            (self.scripts / source.name).chmod(0o755)
        self.runtime = self.root / "runtime"
        self.runtime.mkdir(mode=0o700)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "commands"
        self.environment = os.environ | {
            "RUNTIME_TEST_HOME": str(self.user_home),
            "XDG_RUNTIME_DIR": str(self.runtime),
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "RUNTIME_TEST_LOG": str(self.log),
        }
        for command in ("notify-send", "pkill"):
            self.mock(command, "exit 0")
        self.mock("pgrep", "exit 1")

    def mock(self, command, body):
        path = self.bin / command
        path.write_text("#!/usr/bin/env bash\nset -eu\n" + body + "\n")
        path.chmod(0o755)

    def run_script(self, name, *args, environment=None):
        result = subprocess.run(
            ["bash", str(self.scripts / name), *args],
            env=environment or self.environment,
            capture_output=True,
            text=True,
            timeout=8,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def hold_mock(self, command):
        fifo = self.root / f"{command}-hold"
        os.mkfifo(fifo)
        self.environment["RUNTIME_TEST_HOLD"] = str(fifo)
        self.mock(command, 'printf "%s\\n" "$*" >> "$RUNTIME_TEST_LOG"\nread -r _ < "$RUNTIME_TEST_HOLD"')

    def start_script(self, name):
        process = subprocess.Popen(
            ["bash", str(self.scripts / name)],
            env=self.environment,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
        self.addCleanup(self.stop_process, process)
        deadline = time.monotonic() + 3
        while not self.log.exists():
            self.assertIsNone(process.poll(), process.stderr.read() if process.poll() is not None else "")
            self.assertLess(time.monotonic(), deadline, "mock did not start")
            time.sleep(0.01)
        return process

    @staticmethod
    def stop_process(process):
        if process.poll() is None:
            process.terminate()
        process.communicate(timeout=3)

    @staticmethod
    def stop_process_group(process):
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.communicate(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.communicate(timeout=3)

    def waybar_fixture(self):
        config = self.user_home / ".config/waybar/config.jsonc"
        config.parent.mkdir()
        config.write_text('{"modules-left":["clock"]}')
        self.mock("niri", "printf '%s\\n' '{\"eDP-1\":{\"name\":\"eDP-1\",\"current_mode\":0},\"DP-1\":{\"name\":\"DP-1\",\"current_mode\":0}}'")
        return config

    def sensor_fixture(self, temperature="45000", label="Package id 0"):
        hwmon = self.root / "hwmon/hwmon0"
        hwmon.mkdir(parents=True)
        (hwmon / "name").write_text("coretemp\n")
        (hwmon / "temp1_input").write_text(temperature + "\n")
        (hwmon / "temp1_label").write_text(label + "\n")
        self.environment.update(HWMON_ROOT=str(hwmon.parent), THERMAL_ROOT=str(self.root / "thermal"))
        return hwmon / "temp1_input"

    def test_waybar_keeps_single_instance_and_publishes_complete_config(self):
        self.waybar_fixture()
        self.hold_mock("waybar")
        self.start_script("start-waybar.sh")
        self.run_script("start-waybar.sh")
        self.assertEqual(len(self.log.read_text().splitlines()), 1)
        generated = self.runtime / "hype-waybar-multi-output.json"
        self.assertEqual([bar["output"] for bar in json.loads(generated.read_text())], ["eDP-1", "DP-1"])
        self.assertFalse(list(self.runtime.glob(".hype-waybar.*")))

    def test_failed_waybar_generation_cleans_temporary_file(self):
        config = self.waybar_fixture()
        config.write_text("{ invalid JSON }")
        self.mock("waybar", 'printf "%s\\n" "$*" >> "$RUNTIME_TEST_LOG"')
        self.run_script("start-waybar.sh")
        self.assertIn(str(config), self.log.read_text())
        self.assertFalse(list(self.runtime.glob(".hype-waybar.*")))

    def test_concurrent_sensor_scans_publish_complete_cache(self):
        sensor = self.sensor_fixture(label='Package\t"CPU"')
        with ThreadPoolExecutor(max_workers=8) as executor:
            results = list(executor.map(lambda _: self.run_script("temperature-control.sh"), range(8)))
        for result in results:
            self.assertEqual(json.loads(result.stdout)["text"], "45°")
        cache = (self.runtime / "hype-niri-temp-sensor").read_text()
        self.assertEqual(cache.split("\t", 1)[0], str(sensor))
        self.assertFalse(list(self.runtime.glob(".hype-temp-sensor.*")))
        self.mock("mktemp", "exit 99")
        self.assertEqual(json.loads(self.run_script("temperature-control.sh").stdout)["text"], "45°")

    def test_sensor_cache_does_not_escape_configured_sensor_roots(self):
        self.sensor_fixture("075000")
        unrelated = self.root / "unrelated"
        unrelated.write_text("45000\n")
        (self.runtime / "hype-niri-temp-sensor").write_text(f"{unrelated}\tUnrelated\n")
        result = json.loads(self.run_script("temperature-control.sh").stdout)
        self.assertEqual(result["text"], "75°")
        self.assertEqual(result["class"], "warning")

    def test_wallpaper_ensure_handles_newlines_without_launching_daemon(self):
        wallpapers = self.user_home / "Pictures/Wallpapers"
        wallpapers.mkdir(parents=True)
        image = wallpapers / "one\ntwo.PNG"
        image.touch()
        self.mock("awww", 'printf "unexpected image\\n" >> "$RUNTIME_TEST_LOG"')
        self.mock("awww-daemon", 'printf "unexpected daemon\\n" >> "$RUNTIME_TEST_LOG"')
        with ThreadPoolExecutor(max_workers=6) as executor:
            list(executor.map(lambda _: self.run_script("wallpaper.sh", "ensure"), range(6)))
        current = self.user_home / ".local/state/niri/current_wallpaper"
        self.assertEqual(current.resolve(), image)
        self.assertFalse(self.log.exists())
        self.assertFalse(list(current.parent.glob(".current-wallpaper.*")))

    def test_lock_requests_keep_single_instance(self):
        self.hold_mock("hyprlock")
        self.start_script("lock.sh")
        with ThreadPoolExecutor(max_workers=6) as executor:
            list(executor.map(lambda _: self.run_script("lock.sh"), range(6)))
        self.assertEqual(len(self.log.read_text().splitlines()), 1)

    def test_tray_launcher_keeps_single_instance_without_process_discovery(self):
        self.hold_mock("nm-applet")
        pid_file = self.root / "applet-pid"
        self.environment["RUNTIME_TEST_APPLET_PID"] = str(pid_file)
        self.mock("nm-applet", '''
printf '%s' "$$" > "$RUNTIME_TEST_APPLET_PID"
printf 'nm-applet\\n' >> "$RUNTIME_TEST_LOG"
read -r _ < "$RUNTIME_TEST_HOLD"''')
        self.mock("blueman-applet", "exit 0")
        self.run_script("start-tray-applets.sh")
        deadline = time.monotonic() + 3
        while not pid_file.exists():
            self.assertLess(time.monotonic(), deadline, "applet did not start")
            time.sleep(0.01)
        self.addCleanup(self.terminate_pid, int(pid_file.read_text()))
        with ThreadPoolExecutor(max_workers=6) as executor:
            list(executor.map(lambda _: self.run_script("start-tray-applets.sh"), range(6)))
        self.assertEqual(self.log.read_text().splitlines(), ["nm-applet"])

    def test_volume_parser_preserves_percentage_and_mute_notifications(self):
        self.mock("notify-send", 'printf "%s\\n" "$*" >> "$RUNTIME_TEST_LOG"')
        self.mock("wpctl", "printf 'Volume: 0.65\\n'")
        self.run_script("volume-control.sh")
        self.assertIn("int:value:65", self.log.read_text())
        self.assertIn("Volume: 65%", self.log.read_text())
        self.mock("wpctl", "printf 'Volume: 0.65 [MUTED]\\n'")
        self.run_script("volume-control.sh")
        self.assertIn("Muted", self.log.read_text().splitlines()[-1])

    def test_wallpaper_menu_preserves_newline_filename(self):
        wallpapers = self.user_home / "Pictures/Wallpapers"
        wallpapers.mkdir(parents=True)
        image = wallpapers / "one\ntwo.jpg"
        image.touch()
        self.mock("fuzzel", "cat >/dev/null\nprintf '0\\n'")
        self.mock("pgrep", '[[ "${!#}" == awww-daemon ]]')
        self.mock("awww", "exit 0")
        self.run_script("wallpaper.sh", "select")
        self.assertEqual((self.user_home / ".local/state/niri/current_wallpaper").resolve(), image)

    def test_caffeine_stop_terminates_owned_sleep_child(self):
        pid_file = self.root / "sleep-pid"
        self.environment["RUNTIME_TEST_CHILD_PID"] = str(pid_file)
        program = (
            "import os,subprocess; "
            "child=subprocess.Popen(['/usr/bin/sleep','infinity']); "
            "open(os.environ['RUNTIME_TEST_CHILD_PID'],'w').write(str(child.pid)); "
            "child.wait()"
        )
        self.mock("systemd-inhibit", f"exec -a systemd-inhibit {shlex.quote(shutil.which('python3'))} -c {shlex.quote(program)} \"$@\"")
        result = json.loads(self.run_script("caffeine-control.sh", "toggle").stdout)
        self.assertEqual(result["class"], "activated")
        child_pid = int(pid_file.read_text())
        parent_pid = int((self.runtime / "caffeine_pid").read_text())
        self.addCleanup(self.terminate_pid, child_pid)
        self.addCleanup(self.terminate_pid, parent_pid)
        self.run_script("caffeine-control.sh", "stop")
        self.assertFalse((self.runtime / "caffeine_pid").exists())
        self.assertFalse((self.runtime / "caffeine_state").exists())
        deadline = time.monotonic() + 3
        while self.pid_running(child_pid):
            self.assertLess(time.monotonic(), deadline, "orphaned sleep process survived")
            time.sleep(0.01)

    @staticmethod
    def pid_running(pid):
        try:
            return Path(f"/proc/{pid}/stat").read_text().split(") ", 1)[1][0] != "Z"
        except FileNotFoundError:
            return False

    @staticmethod
    def terminate_pid(pid):
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass

    def test_caffeine_does_not_kill_unrelated_recorded_pid(self):
        process = subprocess.Popen(["sleep", "infinity"])
        self.addCleanup(self.stop_process, process)
        (self.runtime / "caffeine_pid").write_text(f"{process.pid}\n")
        (self.runtime / "caffeine_state").touch()
        self.run_script("caffeine-control.sh", "stop")
        self.assertIsNone(process.poll())

    def test_failed_inhibitor_does_not_leave_active_state(self):
        self.mock("systemd-inhibit", "exit 1")
        result = json.loads(self.run_script("caffeine-control.sh", "toggle").stdout)
        self.assertEqual(result["class"], "deactivated")
        self.assertFalse((self.runtime / "caffeine_pid").exists())
        self.assertFalse((self.runtime / "caffeine_state").exists())

    def test_drive_unlock_removes_passphrase_file_when_interrupted(self):
        device = self.root / "mock-device"
        marker = self.root / "key-file"
        device.touch()
        self.environment.update(RUNTIME_TEST_DEVICE=str(device), RUNTIME_TEST_KEY=str(marker))
        self.mock("lsblk", '''
case "$*" in
    '-prno NAME,FSTYPE') printf '%s crypto_LUKS\\n' "$RUNTIME_TEST_DEVICE" ;;
    '-nrpo NAME '*) printf '%s\\n' "$RUNTIME_TEST_DEVICE" ;;
    '-dno PARTLABEL '*) printf 'Drive\\n' ;;
esac''')
        self.mock("findmnt", "exit 1")
        self.mock("fuzzel", "printf 'test-only-passphrase'")
        preamble = '''
function [ {
    if [[ ${1:-} == -b && ${2:-} == "$RUNTIME_TEST_DEVICE" ]]; then return 0; fi
    builtin [ "$@"
}
udisksctl() {
    printf '%s' "$5" > "$RUNTIME_TEST_KEY"
    sleep 30
}
'''
        process = subprocess.Popen(
            ["bash", "-c", preamble + "source " + shlex.quote(str(self.scripts / "open-drives.sh"))],
            env=self.environment,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
            start_new_session=True,
        )
        self.addCleanup(self.stop_process_group, process)
        deadline = time.monotonic() + 3
        while not marker.exists():
            self.assertIsNone(process.poll(), process.stderr.read() if process.poll() is not None else "")
            self.assertLess(time.monotonic(), deadline, "unlock did not start")
            time.sleep(0.01)
        key_file = Path(marker.read_text())
        self.assertEqual(key_file.read_text(), "test-only-passphrase")
        self.assertEqual(key_file.stat().st_mode & 0o777, 0o600)
        os.killpg(process.pid, signal.SIGTERM)
        process.communicate(timeout=3)
        self.assertFalse(key_file.exists())

    def test_runtime_fallback_rejects_symlink(self):
        helper = self.scripts / "runtime-dir.sh"
        fallback = self.root / "fallback"
        helper.write_text(helper.read_text().replace('/tmp/hype-niri-$UID', str(fallback)))
        fallback.symlink_to(self.runtime, target_is_directory=True)
        result = subprocess.run(
            ["bash", str(helper)],
            env=self.environment | {"XDG_RUNTIME_DIR": str(self.root / "missing")},
            capture_output=True,
            timeout=3,
        )
        self.assertNotEqual(result.returncode, 0)

    def test_runtime_fallback_is_private(self):
        helper = self.scripts / "runtime-dir.sh"
        fallback = self.root / "fallback"
        helper.write_text(helper.read_text().replace('/tmp/hype-niri-$UID', str(fallback)))
        self.run_script("runtime-dir.sh", environment=self.environment | {"XDG_RUNTIME_DIR": str(self.root / "missing")})
        self.assertEqual(fallback.stat().st_mode & 0o777, 0o700)


if __name__ == "__main__":
    unittest.main(verbosity=2)
