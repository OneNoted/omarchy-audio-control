#!/usr/bin/env python3
"""Dismiss the advanced window and its menu when the shared mixer signal fires."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SHELL = Path(os.environ.get('AUDIO_TEST_OMARCHY_SHELL', '/usr/share/omarchy/shell'))
assert all((SHELL/name).is_dir() for name in ('Ui', 'Commons')), 'Set AUDIO_TEST_OMARCHY_SHELL to an Omarchy shell checkout'

with tempfile.TemporaryDirectory(prefix='audio-panel-lifecycle-') as temporary:
    work = Path(temporary)
    for name in ('Ui', 'Commons'):
        (work/name).symlink_to(SHELL/name, target_is_directory=True)
    source = (ROOT/'test/fixtures/panel-lifecycle.qml').read_text()
    fixture = work/'shell.qml'
    fixture.write_text(source.replace('ROOT_URL', json.dumps(ROOT.as_uri()+'/')))
    env = {key: os.environ[key] for key in ('PATH', 'LANG') if key in os.environ}
    env.update(HOME=temporary, XDG_RUNTIME_DIR=temporary, PIPEWIRE_RUNTIME_DIR=temporary,
               PIPEWIRE_REMOTE='absent-panel-test', PULSE_SERVER='unix:'+str(work/'absent-pulse'),
               XDG_CONFIG_HOME=str(work/'config'), XDG_STATE_HOME=str(work/'state'),
               XDG_CACHE_HOME=str(work/'cache'), QT_QPA_PLATFORM='offscreen',
               QT_QUICK_BACKEND='software', DBUS_SYSTEM_BUS_ADDRESS='unix:path='+str(work/'absent-bus'))
    result = subprocess.run(['dbus-run-session', '--', 'quickshell', '--no-color', '--path', str(fixture)],
                            env=env, capture_output=True, text=True, timeout=10)
    output = result.stdout+result.stderr
    assert result.returncode == 0 and 'PANEL_LIFECYCLE_SUCCESS' in output, output
    assert not any(error in output for error in ('PANEL_LIFECYCLE_FAILURE', 'ReferenceError:', 'TypeError:', 'Binding loop')), output
print('PASS: opening the quick mixer closes the advanced window and menus, including proxy summons')
