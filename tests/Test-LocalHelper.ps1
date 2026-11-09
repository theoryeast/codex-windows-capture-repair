# SPDX-License-Identifier: MIT
# Opt-in integration test. Only private file copies are modified.
param([Parameter(Mandatory=$true)][string]$HelperPath)
$ErrorActionPreference='Stop'
$cuRoot=Split-Path -Parent $PSScriptRoot
$cuScript=Join-Path $cuRoot 'Repair-ComputerUse.ps1'
$cuTest=Join-Path $cuRoot ('.local\tests\'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $cuTest -Force | Out-Null
$cuCopy=Join-Path $cuTest 'helper.exe';Copy-Item -LiteralPath $HelperPath -Destination $cuCopy
$cuState=Join-Path $cuTest 'backups'
Add-Type -Path @((Join-Path $cuRoot 'src\CaptureRepair.cs'),(Join-Path $cuRoot 'src\Dispatcher.cs'))
$cuOriginal=[CaptureRepairPE]::Hash([IO.File]::ReadAllBytes($cuCopy))
foreach($cuAction in @('Check','Repair','Check','Repair','Restore')){
  & powershell.exe -NoProfile -File $cuScript -Action $cuAction -HelperPath $cuCopy -BackupDirectory $cuState
  if($LASTEXITCODE -ne 0){throw "Copy integration operation failed: $cuAction"}
}
if([CaptureRepairPE]::Hash([IO.File]::ReadAllBytes($cuCopy)) -ne $cuOriginal){throw 'Restored bytes differ from the signed original.'}
$cuBad=Join-Path $cuTest 'unsupported.exe';$cuBytes=[IO.File]::ReadAllBytes($cuCopy);$cuBytes[1024]=$cuBytes[1024] -bxor 1;[IO.File]::WriteAllBytes($cuBad,$cuBytes)
$cuBefore=[CaptureRepairPE]::Hash($cuBytes);$cuSaved=$ErrorActionPreference;$ErrorActionPreference='Continue'
& powershell.exe -NoProfile -File $cuScript -Action Check -HelperPath $cuBad -BackupDirectory $cuState *> (Join-Path $cuTest 'expected-rejection.txt')
$cuExit=$LASTEXITCODE;$ErrorActionPreference=$cuSaved
if($cuExit -eq 0 -or [CaptureRepairPE]::Hash([IO.File]::ReadAllBytes($cuBad)) -ne $cuBefore){throw 'Unknown-code rejection did not preserve the file.'}
Write-Host 'PASS: check, repair, idempotency, exact restore and unknown-code rejection.'
