# Idempotent task cleanup: one exact disconnected devnode, then its exact package.
# Default Inspect is read-only. No /force, /uninstall, /subtree or trust imports.
[CmdletBinding()]
param([switch]$ApplyAfterUserApproval)
. (Join-Path $PSScriptRoot 'mac1905-temporary-common.ps1')
$id='USB\VID_05AC&PID_1905\00008132-001808291EA2401C'
$nodes=@(Get-PnpDevice -ErrorAction Stop | Where-Object InstanceId -ieq $id)
if($nodes.Count-gt1){throw 'Ambiguous exact devnode result.'}
$nodeExists=($nodes.Count-eq1)
$props=@{}
if($nodeExists){
 Get-PnpDeviceProperty -InstanceId $id -ErrorAction Stop | ForEach-Object {$props[$_.KeyName]=$_.Data}
 if(-not$props.ContainsKey('DEVPKEY_Device_IsPresent')){throw 'Cannot establish non-presence.'}
 if([bool]$props['DEVPKEY_Device_IsPresent']){throw 'Exact target is present. Do not remove it.'}
 if($props['DEVPKEY_Device_Parent']-ine'USB\ROOT_HUB30\4&2720bdb3&0&0' -or $props['DEVPKEY_Device_LocationInfo']-ine'Port_#0013.Hub_#0002' -or $props['DEVPKEY_Device_Service']-ine'WINUSB'){throw 'Historical exact-device identity/port differs from reviewed state.'}
 if('USB\VID_05AC&PID_1905'-notin@($props['DEVPKEY_Device_HardwareIds'])){throw 'Exact hardware ID missing.'}
}
# Read-only hash discovery avoids assuming any reused OEM number identifies our package.
$candidates=@(Get-ChildItem -LiteralPath (Join-Path $env:windir 'INF') -Filter 'oem*.inf' -File | Where-Object {(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash-eq$script:TaskInfHash})
if($candidates.Count-gt1){throw 'Multiple published files share the exact package hash. Stop for review.'}
$published=if($candidates.Count){$candidates[0].Name}else{$null}
if($nodeExists -and (-not$published -or $props['DEVPKEY_Device_DriverInfPath']-ine$published)){throw 'Exact phantom does not use the reviewed hash-matched package.'}
$inspect=[ordered]@{Mode='INSPECT ONLY';InstanceId=$id;NodeExists=$nodeExists;Present=$false;PublishedName=$published;PackageHashFound=($candidates.Count-eq1);OriginalNameRequired='macmini_restore_1905.inf';InfSha256=$script:TaskInfHash;PrivateKeyStillExists=(Test-TaskKeyExists);CertificateOccurrences=@(Find-TaskCertificates);NoActionNeeded=(-not$nodeExists -and -not$published);RemovalRetries=0;PnPConvergenceWaitSeconds=10}
if(-not$ApplyAfterUserApproval){$inspect|ConvertTo-Json -Depth 5;return}
Require-TaskAdmin
Assert-NoTaskRestore
if(@(Find-TaskCertificates).Count -or (Test-TaskKeyExists)){throw 'Security cleanup is incomplete. No trust import permitted.'}
if($inspect.NoActionNeeded){$inspect.Mode='ALREADY CLEAN';$inspect|ConvertTo-Json -Depth 5;return}
$before=@(Get-WindowsDriver -Online -All)
$matches=@($before | Where-Object {$_.Driver-ieq$published -and [IO.Path]::GetFileName($_.OriginalFileName)-ieq'macmini_restore_1905.inf'})
if($matches.Count-ne1){throw 'Hash-matched OEM file is not the exact reviewed original package.'}
$log=Join-Path $script:TaskRoot ('outputs/Mac1905-driver/Phantom-cleanup-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+([guid]::NewGuid().ToString('N').Substring(0,8)))
New-Item -ItemType Directory -Path $log|Out-Null
$inspect|ConvertTo-Json -Depth 5|Set-Content -Encoding utf8 (Join-Path $log 'node-before.json')
$before|Select-Object Driver,OriginalFileName,ProviderName,Version|ConvertTo-Json -Depth 4|Set-Content -Encoding utf8 (Join-Path $log 'drivers-before.json')
$protected=@{};foreach($n in @('oem147.inf','oem178.inf','oem91.inf')){$protected[$n]=(Get-FileHash -LiteralPath (Join-Path $env:windir "INF/$n") -Algorithm SHA256).Hash}
$protected|ConvertTo-Json|Set-Content -Encoding utf8 (Join-Path $log 'protected-apple-before.json')
if($nodeExists){
 $regKey='HKLM\SYSTEM\CurrentControlSet\Enum\'+$id
 & (Join-Path $env:windir 'System32/reg.exe') export $regKey (Join-Path $log 'exact-phantom-node-backup.reg') /y 2>&1|Set-Content -Encoding utf8 (Join-Path $log 'registry-export.txt')
 if($LASTEXITCODE-ne0){throw 'Exact devnode backup failed. No removal performed.'}
 if([bool](Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_IsPresent -ErrorAction Stop).Data){throw 'Target reconnected. Stop.'}
 & (Join-Path $env:windir 'System32/pnputil.exe') /remove-device $id 2>&1|Tee-Object -FilePath (Join-Path $log 'remove-exact-phantom.txt')
 if($LASTEXITCODE-ne0){throw 'Exact removal failed. No retry/force/subtree fallback.'}
 # ONE removal only. Allow PnP's read views up to ten seconds to converge.
 $deadline=[DateTime]::UtcNow.AddSeconds(10)
 do{
  $remaining=@(Get-PnpDevice -ErrorAction Stop | Where-Object InstanceId -ieq $id)
  if(-not$remaining.Count){break}
  $present=Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_IsPresent -ErrorAction SilentlyContinue
  if($present -and [bool]$present.Data){throw 'Target became present during convergence wait.'}
  Start-Sleep -Milliseconds 250
 }while([DateTime]::UtcNow-lt$deadline)
 if($remaining.Count){throw 'PnP did not converge after ten seconds; no package deletion or removal retry.'}
}else{
 'Exact devnode already absent; no devnode removal performed.'|Set-Content -Encoding utf8 (Join-Path $log 'remove-exact-phantom.txt')
}
if(@(Get-PnpDevice -ErrorAction Stop | Where-Object InstanceId -ieq $id).Count){throw 'Exact devnode reappeared. Do not delete package.'}
if((Get-FileHash -LiteralPath (Join-Path $env:windir "INF/$published") -Algorithm SHA256).Hash-ne$script:TaskInfHash){throw 'Package changed during cleanup.'}
& (Join-Path $env:windir 'System32/pnputil.exe') /delete-driver $published 2>&1|Tee-Object -FilePath (Join-Path $log 'delete-exact-package.txt')
$deleteExit=$LASTEXITCODE
$after=@(Get-WindowsDriver -Online -All)
$after|Select-Object Driver,OriginalFileName,ProviderName,Version|ConvertTo-Json -Depth 4|Set-Content -Encoding utf8 (Join-Path $log 'drivers-after.json')
$unexpected=@($before|Where-Object {$_.Driver-notin@($after.Driver) -and $_.Driver-ine$published})
$still=@($after|Where-Object {[IO.Path]::GetFileName($_.OriginalFileName)-ieq'macmini_restore_1905.inf'})
$changedApple=@($protected.Keys|Where-Object {(Get-FileHash -LiteralPath (Join-Path $env:windir "INF/$_") -Algorithm SHA256).Hash-ne$protected[$_]})
$result=[ordered]@{DeleteExitCode=$deleteExit;ExactDevnodeAbsent=$true;DevnodeRemovalPerformed=$nodeExists;Remaining1905PackageCount=$still.Count;UnexpectedDeletedPackages=$unexpected;ChangedAppleInf=$changedApple;RemainingCertificates=@(Find-TaskCertificates);PrivateKeyStillExists=(Test-TaskKeyExists);NoForceUninstallSubtreeOrTrustOperations=$true}
$result|ConvertTo-Json -Depth 5|Tee-Object -FilePath (Join-Path $log 'result.json')
if($deleteExit-ne0 -or $still.Count -or $unexpected.Count -or $changedApple.Count -or $result.RemainingCertificates.Count -or $result.PrivateKeyStillExists){throw 'Cleanup verification failed. Stop; no fallback permitted.'}

