# SPDX-License-Identifier: MIT
$ErrorActionPreference='Stop'
$cuRoot=Split-Path -Parent $PSScriptRoot
$cuFiles=@(& git -C $cuRoot ls-files)
if($LASTEXITCODE -ne 0 -or $cuFiles.Count -eq 0){throw 'Run source checks from an initialized, staged Git checkout.'}
foreach($cuName in $cuFiles){
  if($cuName -match '\.(exe|dll|obj|pdb|bin|zip|log)$' -or $cuName -match '(^|/)(backups|\.local)/'){throw "Private/generated artifact tracked: $cuName"}
  $cuPath=Join-Path $cuRoot $cuName
  $cuText=[IO.File]::ReadAllText($cuPath)
  if($cuText -match '(?i)[a-z]:[\\/]Users[\\/]' -or $cuText -match '(?i)gh[pousr]_[A-Za-z0-9]{25,}'){throw "Possible personal path/token in tracked source: $cuName"}
  if($cuName.EndsWith('.ps1')){
    $cuTokens=$null;$cuErrors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($cuPath,[ref]$cuTokens,[ref]$cuErrors)
    if($cuErrors.Count){throw ($cuErrors | Out-String)}
  }
}
$cuProfile=Get-Content -LiteralPath (Join-Path $cuRoot 'profiles\sky-0.7.17-x64.json') -Raw | ConvertFrom-Json
if($cuProfile.sectionDescriptors.Count -ne 9 -or $cuProfile.normalizedHeaderSha256 -notmatch '^[0-9a-f]{64}$'){throw 'Invalid compatibility profile.'}
Add-Type -Path @((Join-Path $cuRoot 'src\CaptureRepair.cs'),(Join-Path $cuRoot 'src\Dispatcher.cs'))
try{[CaptureRepairPE]::ValidateOriginal([byte[]](0,1,2,3),$cuProfile.normalizedHeaderSha256,[string[]]$cuProfile.sectionDescriptors);throw 'Invalid PE unexpectedly accepted.'}
catch{if($_.Exception.Message -match 'unexpectedly accepted'){throw}}
if([CaptureDispatcher]::Payload(0x17c000).Length -ne 184){throw 'Unexpected dispatcher payload size.'}
Write-Host 'PASS: syntax, compile, profile, invalid-input and tracked-artifact checks.'
