"""Compile the custom RTL and execute reproducible unit simulations."""
from __future__ import annotations
import argparse
import contextlib
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
TESTS = [
    ("tb_ber", "ber_calculator/ber_caculator.v"),
    ("tb_frame_cutter", "frame_cutter/frame_cutter.v"),
    ("tb_frame_boundary", "frame_cutter1/frame_cutter.v"),
    ("tb_serial_tx", "fifo2uart_v2/fifo2uart.v"),
    ("tb_serial_rx", "uart2fifo_v2/uart2fifo_50m.v"),
    ("tb_serial_loopback", ["fifo2uart_v2/fifo2uart.v", "uart2fifo_v2/uart2fifo_50m.v"]),
]

def find_tool(name: str, explicit: str | None, home: Path | None) -> Path:
    if explicit:
        p = Path(explicit).expanduser().resolve()
    elif home:
        p = home / "bin" / (name + (".exe" if os.name == "nt" else ""))
    else:
        found = shutil.which(name)
        if not found:
            raise RuntimeError(f"Cannot find {name}; set ICARUS_HOME or use --{name}.")
        p = Path(found).resolve()
    if not p.is_file():
        raise RuntimeError(f"Executable not found: {p}")
    return p

@contextlib.contextmanager
def windows_tools(cc: Path, sim: Path):
    if os.name != "nt" or cc.parent != sim.parent:
        yield cc, sim
        return
    buf = ctypes.create_unicode_buffer(4096)
    if ctypes.windll.kernel32.GetShortPathNameW(str(sim), buf, len(buf)):
        yield cc, sim
        return
    drive = next((f"{x}:" for x in "ZYXWVUTSRQP" if not Path(f"{x}:/").exists()), None)
    if drive is None:
        raise RuntimeError("No free drive letter for the legacy Windows Icarus installation.")
    subprocess.run(["subst", drive, str(cc.parent.parent)], check=True, capture_output=True)
    try:
        folder = Path(drive + "\\") / "bin"
        yield folder / cc.name, folder / sim.name
    finally:
        subprocess.run(["subst", drive, "/D"], check=True, capture_output=True)

def run(command: list[str | Path], log: Path) -> subprocess.CompletedProcess:
    argv = list(map(str, command))
    display_argv = argv.copy()
    if Path(argv[0]).is_absolute():
        try:
            display_argv[0] = Path(argv[0]).relative_to(ROOT).as_posix()
        except ValueError:
            display_argv[0] = Path(argv[0]).name

    def write_log(exit_code, stdout, stderr):
        def stream(value):
            if isinstance(value, bytes):
                value = value.decode("utf-8", errors="replace")
            return value.rstrip("\n") if value else "(no output)"
        content = (f"command: {subprocess.list2cmdline(display_argv)}\n"
                   f"cwd: . (project root)\nexit_code: {exit_code}\n\n"
                   f"[stdout]\n{stream(stdout)}\n\n[stderr]\n{stream(stderr)}\n")
        log.write_text(content.replace(str(ROOT), ".").replace(ROOT.as_posix(), "."),
                       encoding="utf-8")

    try:
        result = subprocess.run(argv, cwd=ROOT, capture_output=True,
                                text=True, encoding="utf-8", errors="replace", timeout=60)
    except subprocess.TimeoutExpired as exc:
        write_log("unavailable (timed out after 60 seconds)", exc.stdout, exc.stderr)
        raise
    except OSError as exc:
        write_log("unavailable (process did not start)", "", str(exc))
        raise
    write_log(result.returncode, result.stdout, result.stderr)
    return result

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--iverilog", default=os.environ.get("IVERILOG"))
    ap.add_argument("--vvp", default=os.environ.get("VVP"))
    ap.add_argument("--tool-root", default=os.environ.get("ICARUS_HOME"))
    ap.add_argument("--rtl-root", type=Path, default=ROOT / "src/ip_repo")
    ap.add_argument("--output", type=Path, default=ROOT / "sim/results")
    ap.add_argument("--stress", action="store_true", help="Add frame-cutter backpressure testing.")
    ap.add_argument("--waves", action="store_true", help="Write TX/RX VCD waveforms.")
    args = ap.parse_args()
    home = Path(args.tool_root).expanduser().resolve() if args.tool_root else None
    cc = find_tool("iverilog", args.iverilog, home)
    sim = find_tool("vvp", args.vvp, home)
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    tests = []
    sources = {}
    with windows_tools(cc, sim) as (compiler, simulator):
        version = run([compiler, "-V"], out / "simulator_version.log").stdout.splitlines()[0]
        for top, relatives in TESTS:
            relatives = [relatives] if isinstance(relatives, str) else relatives
            source_paths = []
            for relative in relatives:
                source = (args.rtl_root / relative).resolve()
                if not source.is_file():
                    raise RuntimeError(f"RTL source not found: {source}")
                sources[relative] = hashlib.sha256(source.read_bytes()).hexdigest()
                source_paths.append(source)
            artifact = out / (top + ".vvp")
            compile_result = run([compiler, "-g2012", "-Wall", "-s", top, "-o",
                                  os.path.relpath(artifact, ROOT),
                                  *[os.path.relpath(source, ROOT) for source in source_paths], f"sim/{top}.sv"],
                                 out / (top + "_compile.log"))
            commands = [(top, [])]
            if top in ("tb_frame_cutter", "tb_frame_boundary", "tb_serial_rx", "tb_serial_loopback") and args.stress:
                commands.append((top + "_stress", ["+stress"]))
            for label, extra in commands:
                if compile_result.returncode:
                    tests.append({"name": label, "status": "FAIL", "stage": "compile"})
                    continue
                if args.waves and top in ("tb_serial_tx", "tb_serial_rx"):
                    extra = [*extra, "+vcd=" + os.path.relpath(out / (label + ".vcd"), ROOT).replace("\\", "/")]
                result = run([simulator, os.path.relpath(artifact, ROOT), *extra], out / (label + ".log"))
                success = result.returncode == 0 and "PASS " in result.stdout
                tests.append({"name": label, "status": "PASS" if success else "FAIL",
                              "exit_code": result.returncode,
                              "checks": [x for x in result.stdout.splitlines() if x.startswith(("PASS ", "CHECK "))]})
                print(f"{label}: {tests[-1]['status']}")
    passed = all(x["status"] == "PASS" for x in tests)
    summary = {"status": "PASS" if passed else "FAIL", "kind": "RTL simulation",
               "simulator": version, "configuration": {"logic_clock_hz": 200000000,
               "serial_bit_rate_bps": 20000000, "cycles_per_bit": 10,
               "rs_codeword_bytes": 255, "payload_bytes": 239, "sync_bits": 44},
               "tests": tests, "rtl_sha256": sources}
    (out / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0 if passed else 1

if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
