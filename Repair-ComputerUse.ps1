# SPDX-License-Identifier: MIT
[CmdletBinding()]
param(
  [ValidateSet('Repair','Check','Restore','StopCapture')][string]$Action='Check',
  [string]$HelperPath,
  [string]$BackupDirectory
)
$ErrorActionPreference='Stop'
$cuRoot=$PSScriptRoot
if(-not $BackupDirectory){$BackupDirectory=Join-Path $env:LOCALAPPDATA 'CodexCaptureRepair\backups'}
$cuRuntimeRoot=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\runtimes\cua_node'))

function Assert-RegularTarget([string]$File){
  $cuNode=Get-Item -LiteralPath $File -Force
  while($cuNode){
    if(($cuNode.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Reparse-point targets are not supported.'}
    if($cuNode -is [IO.FileInfo]){$cuNode=$cuNode.Directory}else{$cuNode=$cuNode.Parent}
  }
}

function Stop-CaptureSessions {
  $cuItems=@(Get-CimInstance Win32_Process -Filter "Name='codex-computer-use.exe' OR Name='codex-computer-use-swift.exe'" -ErrorAction Stop)
  foreach($cuItem in $cuItems){
    if($cuItem.ExecutablePath -and $cuItem.ExecutablePath.StartsWith($cuRuntimeRoot+'\',[StringComparison]::OrdinalIgnoreCase)){
      $cuWait=Get-Process -Id $cuItem.ProcessId -ErrorAction SilentlyContinue
      if($cuWait){
        Stop-Process -Id $cuItem.ProcessId -ErrorAction Stop
        if(-not $cuWait.WaitForExit(5000)){throw "Capture process did not exit: $($cuItem.ProcessId)"}
        Write-Host "Released capture session: $($cuItem.Name)"
      }
    }
  }
}
function Resolve-Helper {
  if($HelperPath){return (Resolve-Path -LiteralPath $HelperPath -ErrorAction Stop).Path}
  $cuLive=@(Get-CimInstance Win32_Process -Filter "Name='codex-computer-use.exe'" -ErrorAction Stop | Where-Object {$_.ExecutablePath -and $_.ExecutablePath.StartsWith($cuRuntimeRoot+'\',[StringComparison]::OrdinalIgnoreCase)} | Select-Object -ExpandProperty ExecutablePath -Unique)
  if($cuLive.Count -eq 1){return $cuLive[0]}
  if($cuLive.Count -gt 1){throw 'Several active runtimes were found. Close other Computer Use tasks or specify -HelperPath.'}
  $cuCandidates=@(Get-ChildItem -LiteralPath $cuRuntimeRoot -Directory -ErrorAction Stop | Sort-Object LastWriteTime -Descending | ForEach-Object {
    $cuFile=Join-Path $_.FullName 'bin\node_modules\@oai\sky\bin\windows\codex-computer-use.exe'
    if(Test-Path -LiteralPath $cuFile){$cuFile}
  })
  if($cuCandidates.Count -eq 0){throw 'No local Windows Computer Use runtime found. Open Codex once, then retry.'}
  return $cuCandidates[0]
}
function Read-Bytes([string]$File){return ,([IO.File]::ReadAllBytes($File))}
function File-Hash([string]$File){return [CaptureRepairPE]::Hash([IO.File]::ReadAllBytes($File))}
function Write-Verified([string]$File,[byte[]]$Bytes,[string]$Expected){
  if(Test-Path -LiteralPath $File){if((File-Hash $File) -ne $Expected){throw "Existing backup/candidate differs: $File"};return}
  [IO.File]::WriteAllBytes($File,$Bytes)
  if((File-Hash $File) -ne $Expected){throw "Write verification failed: $File"}
}
function Replace-Verified([string]$Target,[string]$Replacement,[string]$Expected,[string]$Rollback,[string]$RollbackHash){
  Assert-RegularTarget $Target
  if((File-Hash $Target) -ne $RollbackHash){throw 'Target changed during preparation; refusing replacement.'}
  Stop-CaptureSessions
  if((File-Hash $Target) -ne $RollbackHash){throw 'Target changed while capture sessions were closing.'}
  for($cuAttempt=0;$cuAttempt -lt 4;$cuAttempt++){
    try{
      $cuStage=Join-Path (Split-Path -Parent $Target) ('capture-repair-'+[guid]::NewGuid().ToString('N')+'.tmp')
      $cuPrevious=$cuStage+'.previous'
      try{
        [IO.File]::WriteAllBytes($cuStage,[IO.File]::ReadAllBytes($Replacement))
        if((File-Hash $Target) -ne $RollbackHash){throw 'Target changed immediately before replacement.'}
        [IO.File]::Replace($cuStage,$Target,$cuPrevious)
      }finally{
        if(Test-Path -LiteralPath $cuStage){Remove-Item -LiteralPath $cuStage -Force}
        if(Test-Path -LiteralPath $cuPrevious){Remove-Item -LiteralPath $cuPrevious -Force}
      }
      if((File-Hash $Target) -ne $Expected){throw 'Installed file hash mismatch.'}
      return
    }catch{
      $cuCopyError=$_
      $cuNow=File-Hash $Target
      if($cuNow -ne $Expected -and $cuNow -ne $RollbackHash){throw 'Target changed outside this operation; refusing to overwrite it during rollback.'}
      if($cuNow -eq $Expected){
        Copy-Item -LiteralPath $Rollback -Destination $Target -Force
        if((File-Hash $Target) -ne $RollbackHash){throw 'Rollback verification failed. Restore the saved original before using Computer Use.'}
        throw $cuCopyError
      }
      if($cuAttempt -lt 3){Start-Sleep -Milliseconds 300;Stop-CaptureSessions;continue}
      throw $cuCopyError
    }
  }
}

try{
  if($Action -eq 'StopCapture'){Stop-CaptureSessions;Write-Host 'Capture sessions released. The yellow capture border should clear.';return}
  if(-not ('CaptureRepairPE' -as [type])){Add-Type -Path @((Join-Path $cuRoot 'src\CaptureRepair.cs'),(Join-Path $cuRoot 'src\Dispatcher.cs'))}
  $cuTarget=Resolve-Helper
  Assert-RegularTarget $cuTarget
  $cuProfile=Get-Content -LiteralPath (Join-Path $cuRoot 'profiles\sky-0.7.17-x64.json') -Raw | ConvertFrom-Json
  $cuCurrentHash=File-Hash $cuTarget
  $cuBackupRoot=[IO.Path]::GetFullPath($BackupDirectory)
  $cuState=$null
  if(Test-Path -LiteralPath $cuBackupRoot){
    foreach($cuStateFile in @(Get-ChildItem -LiteralPath $cuBackupRoot -Filter state.json -File -Recurse)){
      $cuRecord=Get-Content -LiteralPath $cuStateFile.FullName -Raw | ConvertFrom-Json
      if($cuCurrentHash -eq $cuRecord.originalSha256 -or $cuCurrentHash -eq $cuRecord.candidateSha256){$cuState=$cuRecord;break}
    }
  }
  [byte[]]$cuOriginal=$null
  $cuAlreadyPatched=$false
  if($cuState -and $cuCurrentHash -eq $cuState.candidateSha256){
    [byte[]]$cuOriginal=Read-Bytes $cuState.originalBackup
    if([CaptureRepairPE]::Hash($cuOriginal) -ne $cuState.originalSha256){throw 'Saved original backup failed verification.'}
    $cuAlreadyPatched=$true
  }else{
    [byte[]]$cuOriginal=Read-Bytes $cuTarget
    if($Action -eq 'Repair' -or $Action -eq 'Restore'){
      $cuSignature=Get-AuthenticodeSignature -LiteralPath $cuTarget
      if($cuSignature.Status -ne 'Valid'){throw 'Unknown modified helper. Restore your previous repair before using this tool.'}
    }
  }
  [CaptureRepairPE]::ValidateOriginal($cuOriginal,$cuProfile.normalizedHeaderSha256,[string[]]$cuProfile.sectionDescriptors)
  $cuOriginalHash=[CaptureRepairPE]::Hash($cuOriginal)
  Write-Host "Target: $cuTarget"
  Write-Host "Compatibility: reviewed capture code/data match."
  if($Action -eq 'Check'){
    Write-Host $(if($cuAlreadyPatched){'State: repaired (matching saved/known candidate).'}else{'State: compatible original; repair can be applied.'})
    return
  }
  if($Action -eq 'Restore' -and -not $cuAlreadyPatched){Write-Host 'Already original.';return}
  $cuStateDir=Join-Path $cuBackupRoot $cuOriginalHash
  New-Item -ItemType Directory -Path $cuStateDir -Force | Out-Null
  $cuOriginalFile=Join-Path $cuStateDir 'original.bin'
  $cuCandidateFile=Join-Path $cuStateDir 'candidate.bin'
  Write-Verified $cuOriginalFile $cuOriginal $cuOriginalHash
  [byte[]]$cuCandidate=[CaptureRepairPE]::Build($cuOriginal,$cuProfile.normalizedHeaderSha256,[string[]]$cuProfile.sectionDescriptors)
  $cuStaging=Join-Path $cuStateDir ('candidate-'+[guid]::NewGuid().ToString('N')+'.tmp')
  try{
    [CaptureRepairPE]::SaveCandidate($cuStaging,$cuCandidate)
    $cuCandidateHash=File-Hash $cuStaging
    [byte[]]$cuCandidate=Read-Bytes $cuStaging
    Write-Verified $cuCandidateFile $cuCandidate $cuCandidateHash
  }finally{if(Test-Path -LiteralPath $cuStaging){Remove-Item -LiteralPath $cuStaging -Force}}
  if($cuAlreadyPatched -and $cuCurrentHash -ne $cuCandidateHash){throw 'Rebuilt candidate does not match the installed file.'}
  $cuRecord=[ordered]@{target=$cuTarget;originalSha256=$cuOriginalHash;candidateSha256=$cuCandidateHash;originalBackup=$cuOriginalFile;candidate=$cuCandidateFile;preparedAt=(Get-Date).ToString('o');officialUpdate=$false}
  $cuRecord | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $cuStateDir 'state.json') -Encoding UTF8
  if($Action -eq 'Restore'){
    Replace-Verified $cuTarget $cuOriginalFile $cuOriginalHash $cuCandidateFile $cuCandidateHash
    Write-Host 'Original signed helper restored and verified.'
  }elseif($cuAlreadyPatched){Write-Host 'Already repaired; backup and deterministic rebuild verified.'}
  else{
    Write-Host 'Installing the local unsigned compatibility repair; the signed original is backed up.'
    Replace-Verified $cuTarget $cuCandidateFile $cuCandidateHash $cuOriginalFile $cuOriginalHash
    Write-Host 'Repair installed and SHA-256 verified. Test Computer Use in Codex next.'
  }
}finally{
  if($Action -in @('Repair','Restore','StopCapture')){Stop-CaptureSessions}
}
