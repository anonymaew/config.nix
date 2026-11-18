#!/usr/bin/env python3
"""Re-open the editor in a herdr terminal that lost it.

herdr-core restores a pane as a bare shell in its last folder and never re-runs
the original command, so an nvim that was open when the machine rebooted is
gone by design. Every nvim running in a herdr terminal writes a `herdr.nvim`
label (programs/neovim/herdr-sessions.lua) with its folder and the pid of the
shell it ran under. In each restored shell this script compares that pid with
its own: different means a *new* shell inherited the pane, so nvim is started
again from the folder the label recorded (and resession reloads that folder's
session).

Called from the zsh precmd hook in programs/shell/default.nix, once per shell.
Exit code is always 0: a restore that cannot happen must never wedge a prompt.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys


def hc(*args: str) -> str:
    try:
        return subprocess.run(
            ["hc", *args], capture_output=True, text=True, timeout=20
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def main() -> int:
    terminal = os.environ.get("HC_TERMINAL_ID")
    if not terminal:
        return 0  # tmux, ssh, a plain terminal
    if os.environ.get("AGENT_NVIM_AUTO") == "0":
        return 0

    try:
        terminal_info = json.loads(hc("get", terminal))
    except json.JSONDecodeError:
        return 0

    raw = (terminal_info.get("labels") or {}).get("herdr.nvim")
    if not raw:
        return 0  # this pane never held an editor
    try:
        record = json.loads(raw)
    except json.JSONDecodeError:
        return 0

    # Same shell as the one nvim ran under: it is still that shell's editor,
    # not a restore (the user quit nvim themselves).
    if str(record.get("shell")) == str(os.getppid()):
        return 0

    folder = record.get("cwd")
    if not folder or not os.path.isdir(folder):
        return 0

    sys.stderr.write(f"\033[2mnvim-resume: reopening {folder}\033[0m\n")
    sys.stderr.flush()
    try:
        os.chdir(folder)
        # exec, so the pane shows nvim instead of a python wrapper; the shell
        # waits for it and gets its prompt back when nvim exits.
        os.execvp("nvim", ["nvim"])
    except OSError as error:
        sys.stderr.write(f"nvim-resume: could not start nvim: {error}\n")
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
