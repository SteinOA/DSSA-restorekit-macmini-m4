# One-use cleanup after successful restore, including the Mac's post-boot ID.
# Requires the user to disconnect USB. Never removes a present device.
[CmdletBinding()]
param([switch]$ApplyAfterUserApproval)
. (Join-Path $PSScriptRoot 'mac1905-temporary-common.ps1')
$allowed=@{
 'USB\VID_05AC&PID_1905\00008132-001808291EA2401C'=@{Parent='USB\ROOT_HUB30\4&2720bdb3&0&0';Location='Port_#0013.Hub_#0002'}
 'USB\VID_05AC&PID_1905\D6H2HCX7LK'=@{Parent='USB\ROOT_HUB30\7&1b1b327f&6&0';Location='Port_#0004.Hub_#0003'}
}
if(@(Get-PnpDevice -PresentOnly | Where-Object InstanceId -match '^(USB|KIS)\\VID_05AC').Count){throw 'Apple USB still connected. Wait for user disconnection; nothing changed.'}
Assert-NoTaskRestore
if(@(Find-TaskCertificates).Count -or (Test-TaskKeyExists)){throw 'Certificate/key cleanup must already be complete.'}
$nodes=@(Get-PnpDevice | Where-Object InstanceId -like 'USB\VID_05AC&PID_1905\*')
$candidates=@(Get-ChildItem -LiteralPath (Join-Path $env:windir 'INF') -Filter 'oem*.inf' -File | Where-Object {(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash-eq$script:TaskInfHash})
if($candidates.Count-ne1){throw 'Expected exactly one hash-matched reviewed INF.'}
$published=$candidates[0].Name
$remove=@()
foreach($node in $nodes){
 $props=@{};Get-PnpDeviceProperty -InstanceId $node.InstanceId | ForEach-Object {$props[$_.KeyName]=$_.Data}
 if($props['DEVPKEY_Device_DriverInfPath']-ine$published){continue}
 if(-not$allowed.ContainsKey($node.InstanceId)){throw 'Unrecognized instance uses package; nothing changed.'}
 if(-not$props.ContainsKey('DEVPKEY_Device_IsPresent') -or [bool]$props['DEVPKEY_Device_IsPresent']){throw 'Target presence is unsafe or unknown.'}
 $identity=$allowed[$node.InstanceId]
 if($props['DEVPKEY_Device_Parent']-ine$identity.Parent -or $props['DEVPKEY_Device_LocationInfo']-ine$identity.Location -or $props['DEVPKEY_Device_Service']-ine'WINUSB' -or 'USB\VID_05AC&PID_1905'-notin@($props['DEVPKEY_Device_HardwareIds'])){throw 'Exact historical node identity differs.'}
 $remove+=$node.InstanceId
}
if(-not$ApplyAfterUserApproval){[ordered]@{Mode='INSPECT ONLY';PublishedName=$published;InfSHA256=$script:TaskInfHash;ExactAbsentNodes=$remove;Certificates=@(Find-TaskCertificates);PrivateKeyStillExists=(Test-TaskKeyExists)}|ConvertTo-Json -Depth 5;return}
Require-TaskAdmin
$before=@(Get-WindowsDriver -Online -All)
$package=@($before | Where-Object {$_.Driver-ieq$published -and [IO.Path]::GetFileName($_.OriginalFileName)-ieq'macmini_restore_1905.inf'})
if($package.Count-ne1){throw 'Original-name and hash package verification failed.'}
$log=Join-Path $script:TaskRoot ('outputs/Mac1905-driver/Final-attempt9-cleanup-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $log | Out-Null
$before|Select-Object Driver,OriginalFileName,ProviderName,Version|ConvertTo-Json -Depth 4|Set-Content -Encoding utf8 (Join-Path $log 'drivers-before.json')
$protected=@{};foreach($name in @('oem147.inf','oem178.inf','oem91.inf')){$protected[$name]=(Get-FileHash -LiteralPath (Join-Path $env:windir "INF/$name") -Algorithm SHA256).Hash}
# Back up every exact non-present node before performing any removal.
$index=0
foreach($id in $remove){
 $index++
 Get-PnpDeviceProperty -InstanceId $id|Select-Object KeyName,Data|ConvertTo-Json -Depth 5|Set-Content -Encoding utf8 (Join-Path $log ('node-'+$index+'-before.json'))
 & (Join-Path $env:windir 'System32/reg.exe') export ('HKLM\SYSTEM\CurrentControlSet\Enum\'+$id) (Join-Path $log ('node-'+$index+'-backup.reg')) /y 2>&1|Set-Content -Encoding utf8 (Join-Path $log ('node-'+$index+'-backup.log'))
 if($LASTEXITCODE-ne0){throw 'Exact node backup failed; nothing removed.'}
}
foreach($id in $remove){
 Assert-NoTaskRestore
 if(@(Get-PnpDevice -PresentOnly | Where-Object InstanceId -match '^(USB|KIS)\\VID_05AC').Count){throw 'Apple USB reconnected. Stop.'}
 if([bool](Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_IsPresent).Data){throw 'Exact node reconnected. Stop.'}
 & (Join-Path $env:windir 'System32/pnputil.exe') /remove-device $id 2>&1|Add-Content -Encoding utf8 (Join-Path $log 'remove-exact-nodes.log')
 if($LASTEXITCODE-ne0){throw 'Exact removal failed; no retry or force.'}
 $deadline=[DateTime]::UtcNow.AddSeconds(10)
 do{
  $remaining=@(Get-PnpDevice | Where-Object InstanceId -ieq $id)
  if(-not$remaining.Count){break}
  Start-Sleep -Milliseconds 250
 }while([DateTime]::UtcNow-lt$deadline)
 if($remaining.Count){throw 'PnP did not converge; stop without deletion.'}
}
Assert-NoTaskRestore
if(@(Get-PnpDevice -PresentOnly | Where-Object InstanceId -match '^(USB|KIS)\\VID_05AC').Count){throw 'Apple USB reconnected before package deletion.'}
if((Get-FileHash -LiteralPath (Join-Path $env:windir ('INF/'+$published)) -Algorithm SHA256).Hash-ne$script:TaskInfHash){throw 'Reviewed package changed.'}
& (Join-Path $env:windir 'System32/pnputil.exe') /delete-driver $published 2>&1|Set-Content -Encoding utf8 (Join-Path $log 'delete-package.log')
$deleteExit=$LASTEXITCODE
$after=@(Get-WindowsDriver -Online -All)
$after|Select-Object Driver,OriginalFileName,ProviderName,Version|ConvertTo-Json -Depth 4|Set-Content -Encoding utf8 (Join-Path $log 'drivers-after.json')
$unexpected=@($before|Where-Object {$_.Driver-notin@($after.Driver) -and $_.Driver-ine$published})
$remainingPackages=@($after|Where-Object {[IO.Path]::GetFileName($_.OriginalFileName)-in@('macmini_restore_1905.inf','restorekit_winusb.inf')})
$changed=@($protected.Keys|Where-Object {(Get-FileHash -LiteralPath (Join-Path $env:windir "INF/$_") -Algorithm SHA256).Hash-ne$protected[$_]})
$certs=@(Find-TaskCertificates);$key=Test-TaskKeyExists
$result=[ordered]@{Attempt=9;Thumbprint=$script:TaskThumb;DeleteExitCode=$deleteExit;RemovedOnlyNonPresentExactIds=$remove;RemainingRestoreKitPackages=$remainingPackages;UnexpectedDeletedPackages=$unexpected;ChangedAppleInf=$changed;RemainingCertificates=$certs;PrivateKeyStillExists=$key;LocalMachineRootAbsent=(-not(Test-Path -LiteralPath ('Cert:\LocalMachine\Root\'+$script:TaskThumb)));LocalMachineTrustedPublisherAbsent=(-not(Test-Path -LiteralPath ('Cert:\LocalMachine\TrustedPublisher\'+$script:TaskThumb)));CurrentUserMyAbsent=(-not(Test-Path -LiteralPath ('Cert:\CurrentUser\My\'+$script:TaskThumb)));NoForceUninstallSubtreeTrustOrSecurityChanges=$true;Success=($deleteExit-eq0 -and -not$remainingPackages.Count -and -not$unexpected.Count -and -not$changed.Count -and -not$certs.Count -and -not$key)}
$result|ConvertTo-Json -Depth 6|Tee-Object -FilePath (Join-Path $log 'result.json')
if(-not$result.Success){throw 'Final cleanup verification failed. Inspect result.json.'}
