"""Locate Icarus tools and handle legacy Windows executable paths."""
from __future__ import annotations

import argparse
import contextlib
import ctypes
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]


def executable(name: str, explicit: str | None, home: Path | None) -> Path:
    if explicit:
        path = Path(explicit).expanduser().resolve()
    elif home:
        path = home / "bin" / (name + (".exe" if os.name == "nt" else ""))
    else:
        found = shutil.which(name)
        if not found:
            raise RuntimeError(
                f"找不到{name}。请设置ICARUS_HOME或使用--tool-root指定Icarus目录。"
            )
        path = Path(found).resolve()
    if not path.is_file():
        raise RuntimeError(f"程序不存在：{path}")
    return path


@contextlib.contextmanager
def windows_tool_paths(compiler: Path, runtime: Path):
    """Older Windows Icarus builds require a working short executable path.

    A protected workspace can deny GetShortPathName. A temporary drive mapping
    provides a short path to the same tool directory and is removed in finally.
    """
    if os.name != "nt" or compiler.parent != runtime.parent:
        yield compiler, runtime
        return
    buf = ctypes.create_unicode_buffer(4096)
    if ctypes.windll.kernel32.GetShortPathNameW(str(runtime), buf, len(buf)):
        yield compiler, runtime
        return
    home = compiler.parent.parent
    drive = next((f"{letter}:" for letter in "ZYXWVUTSRQP"
                  if not Path(f"{letter}:/").exists()), None)
    if drive is None:
        raise RuntimeError("没有可用于旧版Icarus路径兼容的空闲盘符。")
    subprocess.run(["subst", drive, str(home)], check=True, capture_output=True)
    try:
        base = Path(drive + "\\") / "bin"
        yield base / compiler.name, base / runtime.name
    finally:
        subprocess.run(["subst", drive, "/D"], check=True, capture_output=True)

