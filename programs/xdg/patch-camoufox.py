#!/usr/bin/env python3
"""Give camoufox-cli an XDG home.

camoufox-cli hardcodes two paths under ``~/.camoufox-cli``:

* ``cli.py``     the per-session browser profile dir (``--persistent`` default)
* ``config.py``  the default config file

Neither reads an env var, so the whole ~/.camoufox-cli tree comes back on every
use. This patch makes both honour ``CAMOUFOX_CLI_HOME`` (set to
``$XDG_DATA_HOME/camoufox-cli`` by home.sessionVariables), keeping the old
literal as the fallback so behaviour without the variable is unchanged.

It is a uv tool — writable site-packages, no build step, imported directly —
so the edit is live immediately. ``uv tool upgrade camoufox-cli`` replaces the
files, which is why home.activation.xdgCamoufoxPatch re-runs this on every
switch. Idempotent: a file that already mentions CAMOUFOX_CLI_HOME is skipped,
and a file whose original text no longer matches (upstream rewrote it) is
reported instead of being corrupted.
"""

import glob
import os
import sys

home = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~")
packages = glob.glob(
    f"{home}/.local/share/uv/tools/camoufox-cli/lib/python*/site-packages/camoufox_cli"
)
if not packages:
    print("camoufox-cli: not installed, nothing to patch")
    sys.exit(0)

EDITS = {
    "cli.py": [
        (
            '        flags["persistent"] = os.path.expanduser(f"~/.camoufox-cli/profiles/{flags[\'session\']}")',
            '        _camoufox_home = os.environ.get("CAMOUFOX_CLI_HOME") or "~/.camoufox-cli"\n'
            '        flags["persistent"] = os.path.expanduser(f"{_camoufox_home}/profiles/{flags[\'session\']}")',
        )
    ],
    "config.py": [
        (
            'CONFIG_PATH = os.environ.get("CAMOUFOX_CLI_CONFIG") or os.path.expanduser(\n'
            '    "~/.camoufox-cli/config.json"\n'
            ')',
            '_camoufox_home = os.environ.get("CAMOUFOX_CLI_HOME") or "~/.camoufox-cli"\n'
            'CONFIG_PATH = os.environ.get("CAMOUFOX_CLI_CONFIG") or os.path.expanduser(\n'
            '    f"{_camoufox_home}/config.json"\n'
            ')',
        )
    ],
}

for package in packages:
    for name, edits in EDITS.items():
        path = os.path.join(package, name)
        if not os.path.exists(path):
            continue
        try:
            with open(path) as handle:
                source = handle.read()
        except OSError as error:
            print(f"camoufox-cli: cannot read {path}: {error}", file=sys.stderr)
            continue
        if "CAMOUFOX_CLI_HOME" in source:
            print(f"camoufox-cli: {name} already patched")
            continue
        patched = source
        for old, new in edits:
            if old not in patched:
                print(
                    f"camoufox-cli: {name}: expected text not found, upstream changed it",
                    file=sys.stderr,
                )
                patched = None
                break
            patched = patched.replace(old, new, 1)
        if patched is None:
            continue
        try:
            with open(path, "w") as handle:
                handle.write(patched)
        except OSError as error:
            print(f"camoufox-cli: cannot write {path}: {error}", file=sys.stderr)
            continue
        print(f"camoufox-cli: patched {name}")
