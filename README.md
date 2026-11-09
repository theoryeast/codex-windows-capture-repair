# Windows Computer Use Capture Repair

[中文说明](README.zh-CN.md) · [License](LICENSE) · [Security](SECURITY.md)

An unofficial, reversible workaround for a specific Windows Computer Use failure:
window discovery works, but screenshots fail with `FrameArrived timed out` or
`window capture timed out`, and coordinate clicks have no capture geometry.

**Experimental local compatibility repair.** It modifies a supported installed
helper and therefore produces an unsigned executable. Use an official fix when
one is available. Unknown code/layouts are rejected. No Windows security policy,
certificate trust, app approval, or capture indicator setting is changed.

## Quick start

Download the source ZIP from this repository, extract it, and review the files.
Requirements: Windows x64, Windows PowerShell 5.1, and a locally installed Codex
Computer Use runtime. Normal use requires no Python, native compiler, or network
access. Do not run it during another active Computer Use task.

1. Double-click `Check.cmd` to inspect compatibility.
2. If native screenshots fail on a compatible version, double-click `Repair.cmd`.
3. Test a fresh screenshot, a harmless coordinate click, and another screenshot
   through the original Computer Use API.
4. Use `Stop-Capture.cmd` to release a leftover capture session, or `Restore.cmd`
   to restore the exact original file.

If your organization blocks downloaded PowerShell scripts or unsigned programs,
follow its approved review/signing process. This project does not bypass it.

```powershell
.\Repair-ComputerUse.ps1 -Action Check
.\Repair-ComputerUse.ps1 -Action Repair
.\Repair-ComputerUse.ps1 -Action Restore
.\Repair-ComputerUse.ps1 -Action StopCapture
```

The script defaults to **Check**. Repair and restore are explicit operations.
It first selects a running native helper; otherwise it selects the most recently
unpacked runtime. Use `-HelperPath` to disambiguate multiple installations.
Backups are stored under `%LOCALAPPDATA%\CodexCaptureRepair\backups`, outside
the repository. `-BackupDirectory` overrides this location.

**Migrating from another local patch:** restore that patch with its own tool
before using this implementation. Unknown unsigned files are never patched on
top of an earlier modification.

## How it works

The affected frame callback waits for a SoftwareBitmap conversion while the
capture stack still holds a resource needed by conversion. The dispatcher keeps
the delegate alive, creates a separate Windows Runtime MTA worker, and returns
from the outer callback. The worker runs the original callback, then releases
the delegate and balances successful WinRT initialization with uninitialization.
See [architecture and limits](docs/architecture.md) for the evidence boundary.

The original capture body, coordinate-input code, imports, and base-relocation
table remain intact. The patch adds a small RX section, redirects one reviewed
delegate entry, adds unwind records, and recalculates the PE checksum. The old
certificate directory is cleared because it cannot sign modified bytes.

## Compatibility

The included profile covers the reviewed x64 Sky 0.7.17 layout, observed on
Windows 10 22H2/build 19045. It checks every original PE section and normalized
headers. A version string alone is insufficient.

| Original helper SHA-256 | Status |
| --- | --- |
| `7f73cf564e1f7ff1cc6dff117e2baa6743be2cb5423bdc0f50274fa0e9a4002c` | Locally tested |
| `fc0447efb1aa5a0c527ae88c2ada9ff7ddc398501bf451275218f1f866424ba8` | File-copy integration tested |

A re-signed file can pass if its code/data and reviewed metadata are identical.
If an update changes those bytes, the tool stops without replacing the file.
Future releases are not automatically supported.

## Yellow capture border

Windows draws a yellow border around actively captured items. `Stop-Capture`
ends Codex's local capture helpers so stale sessions can close. It does not hide
the indicator while capture is active or disable the system indicator.
See [Microsoft's screen capture documentation](https://learn.microsoft.com/en-us/windows/apps/develop/media-authoring-processing/screen-capture).

## Validation

- Native harness: 200 asynchronous return-order, MTA, and reference-count checks.
- Source check: emitted machine code and relocations match the repository's MASM
  source. The assembler is needed for contributor tests, not normal use.
- Private local fixture tests: check → repair → check → repair again → restore,
  followed by an unknown-code rejection check. Vendor fixtures are not committed.
- CI validates source and native behavior, not a real Codex/WGC session.

```powershell
.\tests\Test-Sources.ps1
.\tests\Test-Dispatcher.ps1
# Optional: tests file copies only; provide your own signed original.
.\tests\Test-LocalHelper.ps1 -HelperPath 'PATH_TO_YOUR_SIGNED_ORIGINAL.exe'
```

See [contributing](CONTRIBUTING.md), [validation records](docs/validation.md),
and [attribution](NOTICE.md). Licensed under MIT; OpenAI binaries are excluded.
