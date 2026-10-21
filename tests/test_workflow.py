"""Run the real Bash scripts against a simulated device; never invoke real adb."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MOCK_ADB = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
p = pathlib.Path(os.environ['FAKE_DEVICE'])
s = json.loads(p.read_text())
a = sys.argv[1:]
with pathlib.Path(os.environ['FAKE_CALLS']).open('a') as f:
    f.write(json.dumps(a) + '\n')
assert a[:2] == ['-s', 'fake-device'], a
a = a[2:]
if a == ['get-state']:
    print(s.get('connection', 'device'))
    sys.exit(0 if s.get('connection', 'device') == 'device' else 1)
assert a[0] == 'shell', a
a = a[1:]
if a == ['am', 'get-current-user']:
    s['user_queries'] = s.get('user_queries', 0) + 1
    p.write_text(json.dumps(s))
    print('10' if s.get('switch_user') and s['user_queries'] > 1 else s.get('user', '0'))
elif a[:1] == ['getprop']:
    print({'ro.product.model': 'Example Phone', 'ro.build.version.release': '11',
           'ro.miui.ui.version.name': 'V125', 'ro.build.version.security_patch': '2023-07-01'}.get(a[1], ''))
elif a[:1] == ['settings']:
    print(s.get('keyboard', 'com.example.keyboard/.Keyboard'))
elif a[:3] == ['cmd', 'package', 'resolve-activity']:
    print(s.get('launcher', 'com.example.home/.Home'))
elif a[:3] == ['pm', 'list', 'packages']:
    if s.get('bad_inventory'):
        print('Error: invalid user')
    else:
        for pkg in s['packages']:
            print('package:' + pkg)
elif a[:2] == ['pm', 'uninstall']:
    assert a[2:5] == ['-k', '--user', s.get('user', '0')], a
    target = a[5]
    if s.get('uninstall', 'success') != 'stays':
        s['packages'].remove(target)
    if s.get('unrelated_change'):
        s['packages'].remove('com.example.other')
    p.write_text(json.dumps(s))
    mode = s.get('uninstall', 'success')
    if mode in ['error_absent', 'stays']:
        print('Failure [-1000]')
        sys.exit(1)
    print('Success\r' if s.get('crlf') else 'Success')
else:
    raise SystemExit('Unexpected adb command: ' + repr(a))
'''


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        for name in ['inspect.sh', 'remove-reviewed.sh']:
            shutil.copy2(ROOT / name, self.folder / name)
        self.adb = self.folder / 'fake-adb'
        self.adb.write_text(MOCK_ADB)
        self.adb.chmod(0o755)
        self.state = self.folder / 'device.json'
        self.calls = self.folder / 'calls.jsonl'
        self.set_state()
        self.env = dict(os.environ, ADB_BIN=str(self.adb), FAKE_DEVICE=str(self.state), FAKE_CALLS=str(self.calls))

    def set_state(self, **changes):
        state = {'packages': ['com.example.optional', 'com.example.other', 'com.android.systemui',
                              'com.example.keyboard', 'com.example.home']}
        state.update(changes)
        self.state.write_text(json.dumps(state))

    def run_script(self, script, *args, answer=''):
        return subprocess.run(['bash', str(self.folder / script), *args], input=answer,
                              env=self.env, text=True, capture_output=True)

    def assert_no_uninstall(self):
        if self.calls.exists():
            self.assertNotIn('uninstall', self.calls.read_text())

    def test_inspection_reads_only_and_writes_inventory(self):
        result = self.run_script('inspect.sh', 'fake-device')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('No packages changed', result.stdout)
        saved = list((self.folder / 'runs').glob('inspect.*/packages.txt'))
        self.assertEqual(len(saved), 1)
        self.assertIn('package:com.example.optional', saved[0].read_text())
        self.assert_no_uninstall()

    def test_offline_device_refused(self):
        self.set_state(connection='offline')
        for script, args in [('inspect.sh', []), ('remove-reviewed.sh', ['com.example.optional'])]:
            result = self.run_script(script, 'fake-device', *args, answer='REMOVE\n')
            self.assertEqual(result.returncode, 1, result.stderr)
        self.assert_no_uninstall()

    def test_invalid_package_refused_before_adb(self):
        result = self.run_script('remove-reviewed.sh', 'fake-device', 'com.example;reboot')
        self.assertEqual(result.returncode, 2)
        self.assertFalse(self.calls.exists())

    def test_invalid_inventory_refused(self):
        self.set_state(bad_inventory=True)
        result = self.run_script('remove-reviewed.sh', 'fake-device', 'com.example.optional', answer='REMOVE\n')
        self.assertEqual(result.returncode, 1)
        self.assert_no_uninstall()

    def test_essential_keyboard_and_launcher_refused(self):
        for package in ['com.android.systemui', 'com.example.keyboard', 'com.example.home']:
            with self.subTest(package=package):
                result = self.run_script('remove-reviewed.sh', 'fake-device', package, answer='REMOVE\n')
                self.assertEqual(result.returncode, 1, result.stderr)
        self.assert_no_uninstall()

    def test_missing_launcher_refused(self):
        self.set_state(launcher='No activity found')
        result = self.run_script('remove-reviewed.sh', 'fake-device', 'com.example.optional', answer='REMOVE\n')
        self.assertEqual(result.returncode, 1)
        self.assert_no_uninstall()

    def test_cancelled_removal_does_not_mutate(self):
        result = self.run_script('remove-reviewed.sh', 'fake-device', 'com.example.optional', answer='no\n')
        self.assertEqual(result.returncode, 0)
        self.assertIn('Cancelled', result.stdout)
        self.assert_no_uninstall()

    def test_already_absent_does_not_mutate(self):
        result = self.run_script('remove-reviewed.sh', 'fake-device', 'com.example.absent', answer='REMOVE\n')
        self.assertEqual(result.returncode, 0)
        self.assertIn('not installed', result.stdout)
        self.assert_no_uninstall()

    def test_user_switch_refused(self):
        self.set_state(switch_user=True)
        result = self.run_script('remove-reviewed.sh', 'fake-device', 'com.example.optional', answer='REMOVE\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('Active user changed', result.stderr)
        self.assert_no_uninstall()

    def test_success_and_non_owner_user_verification(self):
        self.set_state(user='10')
        result = self.run_script('remove-reviewed.sh', 'fake-device', 'com.example.optional', answer='REMOVE\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('VERIFIED:', result.stdout)
        self.assertIn('user 10', result.stdout)
        self.assertNotIn('com.example.optional', json.loads(self.state.read_text())['packages'])
        after = list((self.folder / 'runs').glob('remove.*/after.txt'))
        self.assertEqual(len(after), 1)

    def test_reported_failure_never_claims_success(self):
        for mode in ['stays', 'error_absent']:
            with self.subTest(mode=mode):
                self.set_state(uninstall=mode)
                result = self.run_script('remove-reviewed.sh', 'fake-device', 'com.example.optional', answer='REMOVE\n')
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertNotIn('VERIFIED:', result.stdout)

    def test_unrelated_package_change_is_flagged(self):
        self.set_state(unrelated_change=True)
        result = self.run_script('remove-reviewed.sh', 'fake-device', 'com.example.optional', answer='REMOVE\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('other package changes', result.stderr)

    def test_crlf_success_output_supported(self):
        self.set_state(crlf=True)
        result = self.run_script('remove-reviewed.sh', 'fake-device', 'com.example.optional', answer='REMOVE\n')
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
