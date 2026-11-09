# Mechanism and boundaries

## Observed failure

Window enumeration and accessibility reads can succeed while Windows Graphics
Capture fails. Without a successful capture, coordinate-input geometry is also
unavailable. Public investigations of the reviewed implementation describe a
callback waiting for SoftwareBitmap conversion while the capture stack retains
a D3D11 resource needed by the conversion worker. This repository does not claim
that every capture timeout has that cause.

## Handoff

`native/dispatcher.asm` implements the outer delegate call. It takes an extra
delegate reference, schedules a worker with `CreateThread`, closes the thread
handle and returns immediately. The worker initializes Windows Runtime as MTA,
runs the original callback and releases the delegate. Successful `RoInitialize`
calls are balanced with `RoUninitialize`.

The reviewed original callback consumes captured delegate state; its sender and
event-args parameters are overwritten before use. That fact is part of the code
fingerprint boundary and must be re-established for any new layout. The worker
passes null for those parameters.

`src/Dispatcher.cs` contains the encoding of this repository's assembly and six
relative fixups. Tests compare it with real assembler output. No downloaded or
bundled executable is used to supply dispatcher machine code.

## PE changes

The profile checks the SHA-256 and layout of all nine original sections. It also
checks normalized header bytes; only the COFF timestamp, checksum and certificate
location may vary. A whole-file version string is never used as the only gate.

The generated candidate adds a 184-byte RX payload with two unwind records,
redirects one existing delegate pointer, and extends `.pdata`. Original code,
imports and relocation entries are retained. The existing DIR64 relocation on
the delegate pointer handles address-space randomization. The obsolete certificate
directory is cleared and the PE checksum is recomputed. The candidate is unsigned.

The installer validates the original signature, saves verified original bytes,
stages the candidate in the target directory and uses `File.Replace` for atomic
replacement. It checks that the target has not changed and verifies the installed
hash. On failure, it attempts to restore the verified pre-operation file.
Reparse-point targets and unknown modifications are rejected.

## Limits

This is a narrow binary compatibility workaround. It is not a general Windows
screen-capture library or an official update. Retaining the delegate is not a
formal proof of the lifetime of everything captured by the original closure.
The worker's eventual HRESULT cannot be returned to an already-completed outer
callback. Thread creation, initialization errors, overlapping captures,
cancellation and long-running sessions require further source-level review.

The yellow border is a Windows capture indicator. Session cleanup ends the
matching local helpers; it does not suppress the active-capture indicator or
modify system permission settings. Another active Computer Use task may therefore
be interrupted by cleanup, which is why the user must finish it first.

## References

- [Public reproduction and MTA investigation](https://github.com/openai/codex/issues/49383)
- [RoInitialize and balanced cleanup](https://learn.microsoft.com/en-us/windows/win32/api/roapi/nf-roapi-roinitialize)
- [Microsoft PE/COFF specification](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format)
- [Windows capture sessions and indicators](https://learn.microsoft.com/en-us/windows/apps/develop/media-authoring-processing/screen-capture)
