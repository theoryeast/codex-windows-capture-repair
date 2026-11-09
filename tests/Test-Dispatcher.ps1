# SPDX-License-Identifier: MIT
$ErrorActionPreference='Stop'
$cuRoot=Split-Path -Parent $PSScriptRoot
$cuVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$cuVs=& $cuVsWhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if(-not $cuVs){throw 'MSVC x64 build tools are required for native contributor tests.'}
$cuVcVars=Join-Path $cuVs 'VC\Auxiliary\Build\vcvars64.bat'
& (Join-Path $cuRoot 'native\build.cmd') $cuVcVars
if($LASTEXITCODE -ne 0){throw 'Native dispatcher test failed.'}
Add-Type -Path (Join-Path $cuRoot 'src\Dispatcher.cs')
$cuObject=[IO.File]::ReadAllBytes((Join-Path $cuRoot 'native\build\dispatcher.obj'))
$cuCount=[BitConverter]::ToUInt16($cuObject,2)
$cuSymbols=[BitConverter]::ToUInt32($cuObject,8)
$cuSymbolCount=[BitConverter]::ToUInt32($cuObject,12)
$cuStrings=$cuSymbols+$cuSymbolCount*18
function Coff-String([int]$Offset){$cuEnd=$Offset;while($cuObject[$cuEnd] -ne 0){$cuEnd++};[Text.Encoding]::UTF8.GetString($cuObject,$Offset,$cuEnd-$Offset)}
$cuNames=@{}
for($cuIndex=0;$cuIndex -lt $cuSymbolCount;){
  $cuAt=$cuSymbols+$cuIndex*18
  if([BitConverter]::ToUInt32($cuObject,$cuAt) -eq 0){$cuName=Coff-String ($cuStrings+[BitConverter]::ToUInt32($cuObject,$cuAt+4))}
  else{$cuName=[Text.Encoding]::ASCII.GetString($cuObject,$cuAt,8).TrimEnd([char]0)}
  $cuNames[$cuIndex]=$cuName;$cuIndex+=1+$cuObject[$cuAt+17]
}
$cuChecked=$false
for($cuIndex=0;$cuIndex -lt $cuCount;$cuIndex++){
  $cuAt=20+$cuIndex*40;$cuName=[Text.Encoding]::ASCII.GetString($cuObject,$cuAt,8).TrimEnd([char]0)
  if($cuName -ne '.text$mn'){continue}
  $cuSize=[BitConverter]::ToUInt32($cuObject,$cuAt+16);$cuRaw=[BitConverter]::ToUInt32($cuObject,$cuAt+20)
  $cuHex=[BitConverter]::ToString($cuObject,$cuRaw,$cuSize).Replace('-','').ToLowerInvariant()
  if($cuHex -ne [CaptureDispatcher]::TemplateHex){throw 'Embedded template does not match the independently assembled source.'}
  $cuRelocs=[BitConverter]::ToUInt32($cuObject,$cuAt+24);$cuRelocCount=[BitConverter]::ToUInt16($cuObject,$cuAt+32)
  if($cuRelocCount -ne [CaptureDispatcher]::RelocationOffsets.Length){throw 'Relocation count differs.'}
  for($cuR=0;$cuR -lt $cuRelocCount;$cuR++){
    $cuPos=$cuRelocs+10*$cuR
    if([BitConverter]::ToUInt32($cuObject,$cuPos) -ne [CaptureDispatcher]::RelocationOffsets[$cuR] -or $cuNames[[int][BitConverter]::ToUInt32($cuObject,$cuPos+4)] -ne [CaptureDispatcher]::RelocationNames[$cuR] -or [BitConverter]::ToUInt16($cuObject,$cuPos+8) -ne 4){throw 'Relocation source/encoding differs.'}
  }
  $cuChecked=$true
}
if(-not $cuChecked){throw 'No native code section found.'}
Write-Host 'PASS: source assembly, emitted template and relocation identities match.'
