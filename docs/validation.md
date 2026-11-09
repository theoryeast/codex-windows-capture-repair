# Validation record

## v0.1.0, 2026-11-09

Environment: Windows 10 Pro 22H2/build 19045, x64, Sky 0.7.17. This is one
local environment, not a claim of general compatibility.

| Check | Result |
| --- | --- |
| Windows PowerShell 5.1 syntax and C# compilation | Passed |
| PowerShell 7 syntax and C# compilation | Passed |
| Native handoff/MTA/refcount harness | 200 iterations, passed |
| Emitted template and relocations versus assembled source | Passed |
| File-copy check/repair/idempotency/exact-restore/rejection | Both listed originals passed |
| Original `@oai/sky` screenshot calls with this source implementation | Three fresh images returned |
| First complete screenshot API call | About 161 ms |
| Screenshot-relative button click | Counter changed from 0 to 1 |
| Fresh content after another capture | Frame counter changed from 0 to 14 to 23 |
| Cleanup | Diagnostic window closed, tool client reset, capture helper sessions released |

Runtime verification used the original supported Computer Use API and a local
diagnostic window. No fallback screenshot library supplied the images. No private
images or logs are published. These checks do not cover every application,
long-running concurrency, cancellation, shutdown races, resource exhaustion or
failure of native thread creation/WinRT initialization.

Original helper used for the live API test:
`7f73cf564e1f7ff1cc6dff117e2baa6743be2cb5423bdc0f50274fa0e9a4002c`

Locally generated candidate for that original:
`7755666a6693c352616389bec0d375202eb441ffa22cd5b95afbdcc622b0d3bb`

The second original, `fc0447ef…f1f866424ba8`, was tested using private file
copies for this implementation. Older experiments used a different dispatcher;
their candidate hashes and runtime observations must not be substituted for this
release's results.

CI exercises source checks and the native harness without proprietary fixtures.
It does not run Codex or demonstrate real WGC capture on GitHub-hosted runners.
