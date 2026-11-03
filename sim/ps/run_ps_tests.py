#!/usr/bin/env python3
"""Compile and execute PS functions against deterministic host API stubs."""
import argparse
from hashlib import sha256
import importlib.util
import json
import os
from pathlib import Path
import queue
import shutil
import socket
import subprocess
import threading

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
TEST_CHECKS = {
    "test_udp": [
        "uninitialized sender rejects data",
        "five valid lengths are allocated, copied, sent and freed",
        "zero length, null data and oversized payload are rejected",
        "allocation failure does not send data",
        "bind and connect failures remove the PCB and reject data",
    ],
    "test_dma": [
        "missing configuration, initialization failure and SG mode are rejected",
        "invalid lengths and failed transfer are rejected",
        "300-byte transfer flushes cache before starting DMA",
        "completion sets the done flag and invalidates cache",
        "error interrupt clears completion and disables channel interrupts",
        "recovery clears flags and reenables interrupts",
        "reset timeout reports failure",
    ],
    "test_main": [
        "main loop returns the expected recovery failure",
        "five loop iterations execute three start and three recovery calls",
        "one 239-byte UDP payload is sent and DMA flags are cleared",
    ],
}


def command(args, output, name, checks=None):
    argv = [str(x) for x in args]
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
        if exit_code == 0 and checks:
            content += "\n[completed checks]\n" + "\n".join("PASS " + item for item in checks) + "\n"
        (output / (name + ".log")).write_text(
            content.replace(str(ROOT), ".").replace(ROOT.as_posix(), "."), encoding="utf-8")

    try:
        result = subprocess.run(argv, cwd=ROOT, capture_output=True,
                                encoding="utf-8", errors="replace", timeout=60)
    except subprocess.TimeoutExpired as exc:
        write_log("unavailable (timed out after 60 seconds)", exc.stdout, exc.stderr)
        raise
    except OSError as exc:
        write_log("unavailable (process did not start)", "", str(exc))
        raise
    write_log(result.returncode, result.stdout, result.stderr)
    if result.returncode:
        raise RuntimeError(f"{name} failed ({result.returncode}): "
                           + result.stdout + result.stderr)
    return result


def udp_loopback(output):
    module_path = ROOT / "board/receive_udp.py"
    spec = importlib.util.spec_from_file_location("uwoc_receiver", module_path)
    receiver = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(receiver)
    ready, returned = queue.Queue(), queue.Queue()
    capture_path = output / "udp_capture.bin"
    payloads = [bytes((i + j) & 255 for j in range(239)) for i in range(3)]

    def worker():
        try:
            returned.put(receiver.capture("127.0.0.1", 0, capture_path,
                         packets=3, timeout=3, quiet=True, on_ready=ready.put))
        except BaseException as error:
            returned.put(error)

    thread = threading.Thread(target=worker, daemon=True)
    thread.start()
    address = ready.get(timeout=5)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sender:
        for payload in payloads:
            sender.sendto(payload, address)
    thread.join(timeout=5)
    if thread.is_alive():
        raise RuntimeError("UDP receiver did not stop")
    result = returned.get(timeout=1)
    if isinstance(result, BaseException):
        raise result
    assert capture_path.read_bytes() == b"".join(payloads)
    assert result["packets"] == 3 and result["bytes"] == 717
    assert result["different_length_packets"] == 0
    return {"status": "pass", "packets": 3, "bytes": 717}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cc", default=os.environ.get("CC") or shutil.which("clang") or shutil.which("gcc"))
    parser.add_argument("--linker", help="On Windows, lld.exe or lld-link.exe")
    parser.add_argument("--output", default=str(ROOT / "build/results/ps_tests"))
    args = parser.parse_args()
    if not args.cc:
        parser.error("A C compiler is required. Pass --cc or put clang/gcc on PATH.")
    cc = Path(shutil.which(args.cc) or args.cc).expanduser().resolve()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    version = command([cc, "--version"], output, "compiler_version").stdout.splitlines()[0]
    results = {}
    for name in ["test_udp", "test_dma", "test_main"]:
        source = HERE / (name + ".c")
        obj = output / (name + ".obj")
        executable = output / (name + (".exe" if os.name == "nt" else ""))
        base = [cc, "-std=c99", "-Wall", "-Wextra", "-ffreestanding",
                "-fno-builtin", "-fno-stack-protector", "-nostdinc",
                "-I", HERE / "stubs", "-I", ROOT / "src/ps/rx"]
        if os.name == "nt":
            command(base + ["-c", source, "-o", obj], output, name + "_compile")
            linker = (Path(shutil.which(args.linker) or args.linker).expanduser().resolve()
                      if args.linker else cc.with_name("lld.exe"))
            if not linker.exists():
                raise FileNotFoundError("Pass --linker with lld.exe or lld-link.exe")
            flavor = ["-flavor", "link"] if linker.name.lower() == "lld.exe" else []
            command([linker, *flavor, "/entry:main", "/subsystem:console", "/nodefaultlib",
                     "/out:" + str(executable), obj], output, name + "_link")
        else:
            command(base + [source, "-o", executable], output, name + "_compile")
        command([executable], output, name + "_run", checks=TEST_CHECKS[name])
        results[name] = {"status": "pass", "exit_code": 0, "checks": TEST_CHECKS[name]}
        print(f"PASS {name}: {len(TEST_CHECKS[name])} completed check groups")
    results["udp_loopback"] = udp_loopback(output)
    sources = sorted(
        [p for p in (ROOT / "src/ps/rx").rglob("*") if p.suffix in (".c", ".h")]
        + list(HERE.glob("test*.c"))
        + list((HERE / "stubs").rglob("*.h")))
    report = {"status": "pass", "test_kind": "host C functions with API stubs and UDP loopback",
              "compiler": version, "checks": results,
              "source_sha256": {p.relative_to(ROOT).as_posix(): sha256(p.read_bytes()).hexdigest()
                                for p in sources}}
    (output / "ps_test_results.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
