# Contributing

Issues and pull requests are welcome. Start with a minimal reproduction and the
helper's SHA-256, Sky version and Windows build. Do not upload executables,
screenshots of private windows, raw application logs, account data or tokens.

## Development

Normal use requires Windows PowerShell 5.1. Contributor native tests additionally
require Visual Studio C++ x64 build tools and a Windows SDK. No third-party
PowerShell modules are needed.

```powershell
.\tests\Test-Sources.ps1
.\tests\Test-Dispatcher.ps1
# Optional signed fixture from your own installation; copies are used.
.\tests\Test-LocalHelper.ps1 -HelperPath 'PATH_TO_YOUR_SIGNED_ORIGINAL.exe'
```

Do not commit the fixture, `.local`, backups, generated candidates or debug symbols.
The native harness tests delegate handoff. It cannot establish actual WGC/runtime
compatibility. For a runtime change, separately verify repeated fresh captures,
a harmless screenshot-relative click, the changed target in another screenshot,
and cleanup through the original API. Record scope and failures accurately.

## New compatibility profiles

Do not replace an expected hash merely to make a new build pass. Review the
callback's arguments and captured-object lifetime, imports, layout, relocation
coverage and unwind data. Supply reproducible structural evidence and local
runtime results. Fingerprints and metadata may be contributed; proprietary
executables may not. Profile changes require maintainer review.

By contributing, you agree that your original contribution is provided under the
repository's MIT license. Identify any third-party content and its license.
