#!/usr/bin/env python3
"""Receive the terminal's UDP information frames into a binary file."""
import argparse
import hashlib
import json
from pathlib import Path
import socket
import time


def capture(bind_ip, port, output, packets=0, timeout=0.0,
            expected_length=239, quiet=False, on_ready=None):
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256()
    count = total = different_length = 0
    started = time.monotonic()
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as receiver:
        receiver.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4 * 1024 * 1024)
        receiver.bind((bind_ip, port))
        if timeout > 0:
            receiver.settimeout(timeout)
        address = receiver.getsockname()
        if not quiet:
            print(f"Listening on {address[0]}:{address[1]}", flush=True)
        if on_ready:
            on_ready(address)
        with output.open("wb") as stream:
            try:
                while packets == 0 or count < packets:
                    data, _peer = receiver.recvfrom(65535)
                    stream.write(data)
                    digest.update(data)
                    count += 1
                    total += len(data)
                    different_length += int(len(data) != expected_length)
                    if not quiet and count % 1000 == 0:
                        print(f"packets={count} bytes={total}", flush=True)
            except (KeyboardInterrupt, socket.timeout):
                pass
    elapsed = time.monotonic() - started
    result = {
        "bind_ip": bind_ip, "port": address[1], "packets": count,
        "bytes": total, "expected_packet_length": expected_length,
        "different_length_packets": different_length,
        "elapsed_seconds": elapsed, "sha256": digest.hexdigest(),
    }
    output.with_suffix(output.suffix + ".json").write_text(
        json.dumps(result, indent=2), encoding="utf-8")
    if not quiet:
        print(json.dumps(result, indent=2))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bind", default="192.168.253.104")
    parser.add_argument("--port", type=int, default=5001)
    parser.add_argument("--output", default="data/capture/received.bin")
    parser.add_argument("--packets", type=int, default=0,
                        help="Stop after this many packets; 0 runs until Ctrl+C.")
    parser.add_argument("--timeout", type=float, default=0.0,
                        help="Stop after this many seconds without a datagram.")
    parser.add_argument("--expected-length", type=int, default=239)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()
    if args.packets < 0 or args.timeout < 0 or not 0 <= args.port <= 65535:
        parser.error("packets, timeout and port must be within range")
    capture(args.bind, args.port, args.output, args.packets, args.timeout,
            args.expected_length, args.quiet)


if __name__ == "__main__":
    main()
