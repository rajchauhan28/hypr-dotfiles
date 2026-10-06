#!/usr/bin/env python3
"""Print the platform profile each time it changes, one name per line.

The kernel raises sysfs_notify() on this attribute whenever the profile moves:
the Predator mode/turbo key cycling it inside linuwu_sense, power-profiles-daemon
writing it, or DAMX. So this blocks in poll() and costs nothing between changes.
The value at startup is deliberately not printed -- the OSD pops on changes only.
Exits quietly on machines without a platform profile.
"""
import ctypes
import select
import signal
import sys

PATH = "/sys/firmware/acpi/platform_profile"
PR_SET_PDEATHSIG = 1


def read(f):
    # Reading from offset 0 is also what re-arms the sysfs notification.
    f.seek(0)
    return f.read().strip()


def main():
    # Die with the shell even when it is SIGKILLed (reload.sh does that to a
    # wedged instance); otherwise this would sit in poll() as an orphan.
    try:
        ctypes.CDLL(None, use_errno=True).prctl(PR_SET_PDEATHSIG, signal.SIGTERM)
    except (OSError, AttributeError):
        pass
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    try:
        f = open(PATH)
    except OSError:
        return
    last = read(f)
    poller = select.poll()
    poller.register(f, select.POLLPRI | select.POLLERR)
    while True:
        poller.poll()
        try:
            cur = read(f)
        except OSError:
            return
        if cur and cur != last:
            last = cur
            print(cur, flush=True)


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        sys.exit(0)
