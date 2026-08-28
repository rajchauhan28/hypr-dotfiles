# damx-driver

Assets for the Acer Predator/Nitro `linuwu_sense` kernel module, driven by
`~/.local/bin/damx-driver-manager` and by the Settings app's Maintenance page
(`quickshell/settings/MaintenancePage.qml`).

## Licensing

`source/` is **third-party GPL-3 code and is not covered by this repository's
MIT licence.** Its own `source/LICENSE` (GPL-3) governs it and travels with it.

Lineage:

1. [`0x7375646F/Linuwu-Sense`](https://github.com/0x7375646F/Linuwu-Sense) —
   the original Acer WMI fork.
2. **DAMX-Sense** — a further fork by Div Sharp for
   [`PXDiv/Div-Acer-Manager-Max`](https://github.com/PXDiv/Div-Acer-Manager-Max).
   Note the module source is *not* in that repository's tree; it ships inside
   its release tarballs.
3. A local patch replacing the three `strncpy` calls that kernel 7.2 removed,
   without which the module does not compile on a current CachyOS kernel.

## Why it is vendored

It cannot be recovered by cloning anything. Upstream Linuwu-Sense still has the
`strncpy` calls and will not build here; PXDiv's repository does not carry the
source at all. This directory is the only buildable copy, and there is no DKMS
setup, so it is needed again after every kernel upgrade.

`damx-suite-installer` is gitignored on purpose: it only downloads an upstream
release tarball, so pinning a snapshot of it buys nothing.
