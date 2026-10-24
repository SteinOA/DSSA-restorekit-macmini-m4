# REVIEW DRAFT. Call from the restore orchestrator's finally after process completion.
# Default inspection neither imports certificates nor removes packages.
[CmdletBinding()]
param([switch]$ApplyAfterUserApproval)
. (Join-Path $PSScriptRoot 'mac1905-temporary-common.ps1')
$state=[ordered]@{Mode='INSPECT ONLY';Thumbprint=$script:TaskThumb;Certificates=@(Find-TaskCertificates);PrivateKeyStillExists=(Test-TaskKeyExists);PackageIdentification='OriginalName macmini_restore_1905.inf AND reviewed SHA256; never an OEM number alone'}
if(-not$ApplyAfterUserApproval){$state | ConvertTo-Json -Depth 5;return}
Require-TaskAdmin
Assert-NoTaskRestore
$log=Join-Path $script:TaskRoot ('outputs/Mac1905-driver/Cleanup-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $log | Out-Null
$state | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 (Join-Path $log 'before.json')
$errors=[Collections.Generic.List[string]]::new()
$beforeDrivers=@();$protected=@{}
try {
 $beforeDrivers=@(Get-WindowsDriver -Online -All)
 foreach($name in @('oem147.inf','oem178.inf','oem91.inf')){$protected[$name]=(Get-FileHash -LiteralPath (Join-Path $env:windir "INF/$name") -Algorithm SHA256).Hash}
 $packages=@($beforeDrivers | Where-Object {[IO.Path]::GetFileName($_.OriginalFileName)-ieq'macmini_restore_1905.inf'})
 if($packages.Count-gt1){throw 'Multiple exact original-name packages; do not guess.'}
 foreach($package in $packages){
  $published=$package.Driver
  if($published-notmatch'^oem\d+\.inf$'){throw 'Unexpected published package name.'}
  if((Get-FileHash -LiteralPath (Join-Path $env:windir "INF/$published") -Algorithm SHA256).Hash-ne$script:TaskInfHash){throw 'Package hash mismatch; no deletion performed.'}
  $using=@(Get-PnpDevice -PresentOnly | Where-Object {$_.InstanceId-like'USB\VID_05AC&PID_1905\*'} | ForEach-Object {
   $device=$_
   if($device.InstanceId-ine'USB\VID_05AC&PID_1905\00008132-001808291EA2401C'){throw 'Unexpected present Apple1905 instance; do not modify this package.'}
   $properties=@{};Get-PnpDeviceProperty -InstanceId $device.InstanceId -ErrorAction Stop | ForEach-Object {$properties[$_.KeyName]=$_.Data}
   if(-not$properties.ContainsKey('DEVPKEY_Device_DriverInfPath')){throw 'Cannot verify current1905 driver binding.'}
   if([string]$properties['DEVPKEY_Device_DriverInfPath']-ieq$published){$device}
  })
  if($using.Count){throw 'Exact package still used by the present Mac1905. Disconnect the restored Mac; never force removal.'}
  & (Join-Path $env:windir 'System32/pnputil.exe') /delete-driver $published 2>&1 | Tee-Object -FilePath (Join-Path $log 'driver-removal.txt')
  if($LASTEXITCODE-ne0){throw 'Package removal failed; no force/uninstall fallback is permitted.'}
 }
} catch {$errors.Add($_.Exception.Message)} finally {
 # Security cleanup is independent of driver-removal success. Exact thumb only.
 foreach($entry in @(Find-TaskCertificates | Sort-Object @{Expression={if($_.Path-like'Cert:\LocalMachine\*'){0}else{1}}},Path)){
  try{
   if(Test-Path -LiteralPath $entry.Path){
    if($entry.Subject-ne'CN=RestoreKit WinUSB'){throw 'Exact-thumb certificate has unexpected subject.'}
    if($entry.HasPrivateKey){Remove-Item -LiteralPath $entry.Path -DeleteKey -Confirm:$false}else{Remove-Item -LiteralPath $entry.Path -Confirm:$false}
   }
  }catch{$errors.Add($_.Exception.Message)}
 }
 if(Test-TaskKeyExists){
  try{$key=[Security.Cryptography.CngKey]::Open($script:TaskKey,[Security.Cryptography.CngProvider]::new('Microsoft Software Key Storage Provider'),[Security.Cryptography.CngKeyOpenOptions]::None);try{$key.Delete()}finally{$key.Dispose()}}catch{$errors.Add($_.Exception.Message)}
 }
}
$remainingCerts=@(Find-TaskCertificates)
$keyExists=Test-TaskKeyExists
$afterDrivers=@(Get-WindowsDriver -Online -All)
$remainingPackages=@($afterDrivers | Where-Object {[IO.Path]::GetFileName($_.OriginalFileName)-ieq'macmini_restore_1905.inf'})
$unexpectedDeleted=@($beforeDrivers | Where-Object {$_.Driver-notin@($afterDrivers.Driver) -and [IO.Path]::GetFileName($_.OriginalFileName)-ine'macmini_restore_1905.inf'})
foreach($name in $protected.Keys){if((Get-FileHash -LiteralPath (Join-Path $env:windir "INF/$name") -Algorithm SHA256).Hash-ne$protected[$name]){$errors.Add("Protected Apple INF changed: $name")}}
if($remainingCerts.Count -or $keyExists -or $remainingPackages.Count -or $unexpectedDeleted.Count){$errors.Add('Final cleanup incomplete; inspect exact residual objects in result.json.')}
[ordered]@{Thumbprint=$script:TaskThumb;RemainingCertificates=$remainingCerts;PrivateKeyStillExists=$keyExists;Remaining1905Packages=$remainingPackages;UnexpectedDeletedPackages=$unexpectedDeleted;Errors=@($errors);Success=($errors.Count-eq0);NoSignatureChainVerificationRun=$true} | ConvertTo-Json -Depth 5 | Tee-Object -FilePath (Join-Path $log 'result.json')
if($errors.Count){throw ($errors -join '; ')}

