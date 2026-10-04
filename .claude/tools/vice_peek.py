#!/usr/bin/env python3
"""vice_peek.py - run a .prg in VICE, then read memory and/or screenshot it.

The shared measurement tool for C64 work in this repo, so that a reviewer
agent never has to write its own remote-monitor harness (that, plus sleep
polling, was most of the time in the long c64-reviewer runs).

    vice_peek.py PRG --seconds S [--pal] [--mem START END]... [--shot FILE]

  --seconds S  emulated seconds after the program starts (boot is added)
  --pal        PAL instead of the default NTSC - this repo targets NTSC first
  --mem A B    hex range to dump, e.g. --mem c000 c03f (repeatable)
  --shot FILE  PNG screenshot at the same moment
  --boot N     cycles VICE spends booting + autostarting (default 3200000)

Timing: runs in warp until ~2M cycles short of the target, then at normal
speed, polling the monitor's CPU stopwatch; it stops within about a frame of
the target and prints the cycle it actually stopped at. A screenshot-only
run uses -limitcycles instead, which is exact.

Rules it enforces, because concurrent agents broke each other's runs:
  - a free TCP port per run (never a fixed 6510), so runs can go in parallel;
  - it only ever kills the VICE it started - its own process group, since
    bin/x64sc is a launcher script (never `pkill x64sc`).
"""
import argparse, os, re, signal, socket, subprocess, sys, time

X64SC = "/Applications/vice-arm64-gtk3/bin/x64sc"
HZ = {"ntsc": 1022727, "pal": 985248}


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


class Monitor:
    def __init__(self, port):
        self.sock = None
        for _ in range(200):
            try:
                self.sock = socket.create_connection(("127.0.0.1", port), timeout=1)
                break
            except OSError:
                time.sleep(0.05)
        if self.sock is None:
            sys.exit("vice_peek: could not reach the VICE remote monitor")
        self.sock.settimeout(30)
        self.buf = b""

    def drain(self):
        """Throw away anything VICE has sent that nobody asked for (the
        prompt it prints when it breaks in, stale output, ...)."""
        self.sock.settimeout(0.15)
        try:
            while self.sock.recv(65536):
                pass
        except (socket.timeout, BlockingIOError):
            pass
        self.sock.settimeout(30)
        self.buf = b""

    def send(self, line):
        self.sock.sendall((line + "\n").encode())

    def ask(self, line, marker):
        """Send a command and read until `marker` has arrived AND a prompt
        follows it. Breaking into a running machine emits a bare prompt
        before the command's own output; waiting for the marker skips it."""
        self.drain()
        self.send(line)
        while True:
            k = self.buf.find(marker)
            if k >= 0:
                m = re.search(rb"\(C:\$[0-9a-f]{4}\) ", self.buf[k:])
                if m:
                    return self.buf[:k + m.end()].decode(errors="replace")
            data = self.sock.recv(65536)
            if not data:
                return self.buf.decode(errors="replace")
            self.buf += data

    def clock(self):
        """Break in (if running) and return the CPU stopwatch, in cycles."""
        out = self.ask("r", b".;")
        m = re.search(r"^\.;[0-9a-f]{4} .*?(\d+)\s*$", out, re.M)
        return int(m.group(1))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("prg")
    ap.add_argument("--seconds", type=float, required=True)
    ap.add_argument("--pal", action="store_true")
    ap.add_argument("--mem", nargs=2, action="append", default=[],
                    metavar=("START", "END"))
    ap.add_argument("--shot")
    ap.add_argument("--boot", type=int, default=3200000)
    a = ap.parse_args()

    std = "pal" if a.pal else "ntsc"
    target = a.boot + int(a.seconds * HZ[std])

    if not a.mem:                       # screenshot only: exact, no monitor
        if not a.shot:
            sys.exit("vice_peek: nothing to do (give --mem and/or --shot)")
        subprocess.run([X64SC, "-" + std, "-warp", "-limitcycles", str(target),
                        "-exitscreenshot", os.path.abspath(a.shot), "-autostart", a.prg],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"{std} cycle {target}: screenshot {a.shot}")
        return

    port = free_port()
    proc = subprocess.Popen([X64SC, "-" + std, "-warp", "-remotemonitor",
                             "-remotemonitoraddress", f"ip4://127.0.0.1:{port}",
                             "-autostart", a.prg],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                            start_new_session=True)
    try:
        mon = Monitor(port)
        warp = True
        while True:
            clk = mon.clock()
            if clk >= target:
                break
            if warp and target - clk < 3000000:
                mon.ask("warp off", b"")
                warp = False
            mon.send("x")               # resume; the next command breaks in
            # warp runs ~13M cycles a host second, normal speed ~1M: sleep
            # most of the remaining distance, then check again
            # (warp speed varies with the host; 40M/s is an upper bound)
            rate = 40e6 if warp else 1.2e6
            time.sleep(min(0.5, max(0.01, (target - clk) / rate)))
        print(f"{std} cycle {clk} (target {target}, "
              f"+{(clk - target) / HZ[std] * 1000:.0f} ms)")
        for start, end in a.mem:
            out = mon.ask(f"m {start} {end}", b">C:")
            print("\n".join(l[l.index(">C:"):] for l in out.splitlines() if ">C:" in l))
        if a.shot:
            mon.ask(f'screenshot "{os.path.abspath(a.shot)}" 2', b"")
            print(f"screenshot {a.shot}")
    finally:
        # bin/x64sc is a launcher script that starts the real emulator as a
        # child: killing proc alone leaves VICE running. Kill the group.
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass


if __name__ == "__main__":
    main()
