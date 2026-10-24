# REVIEW DRAFT. No mutation unless -ApplyAfterUserApproval is explicitly supplied.
[CmdletBinding()]
param([switch]$ApplyAfterUserApproval)
. (Join-Path $PSScriptRoot 'mac1905-temporary-common.ps1')
$cert=Read-TaskPublicCertificate
$basic=@($cert.Extensions | Where-Object {$_.Oid.Value-eq'2.5.29.19'})
$inspect=[ordered]@{Mode='INSPECT ONLY';Target='USB\VID_05AC&PID_1905';Thumbprint=$cert.Thumbprint;PublicOnly=(-not$cert.HasPrivateKey);BasicConstraintsPresent=($basic.Count-gt0);PrivateKeyStillExists=(Test-TaskKeyExists);InfSha256=$script:TaskInfHash;CatSha256=$script:TaskCatHash;PlannedTrustStores=@('LocalMachine/Root','LocalMachine/TrustedPublisher');NewCertificateOrKeyCreated=$false;PackageInstalled=$false;ExistingCertificateOccurrences=@(Find-TaskCertificates)}
if(-not$ApplyAfterUserApproval){try{$inspect | ConvertTo-Json -Depth 5}finally{$cert.Dispose()};return}
Require-TaskAdmin
Assert-NoTaskRestore
if(Test-TaskKeyExists){throw 'Deleted historical private key unexpectedly exists. Stop for review.'}
$present=@(Get-PnpDevice -PresentOnly | Where-Object {$_.InstanceId-match '^(USB|KIS)\\VID_05AC'})
if($present.Count){throw 'This staging preparation requires all Apple USB devices absent, so no live binding can be affected.'}
$preexisting=@(Find-TaskCertificates);if($preexisting.Count){throw 'Expected prior cleanup to leave this exact certificate absent from all stores.'}
$before=@(Get-WindowsDriver -Online -All)
if(@($before | Where-Object {[IO.Path]::GetFileName($_.OriginalFileName)-ieq'macmini_restore_1905.inf'}).Count){throw 'Exact 1905 package already exists. Stop for review.'}
$protected=@{};foreach($name in @('oem147.inf','oem178.inf','oem91.inf')){$protected[$name]=(Get-FileHash -LiteralPath (Join-Path $env:windir "INF/$name") -Algorithm SHA256).Hash}
$log=Join-Path $script:TaskRoot ('outputs/Mac1905-driver/Temporary-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $log | Out-Null
$before | Select-Object Driver,OriginalFileName,ProviderName,Version | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 (Join-Path $log 'driver-before.json')
$inspect | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 (Join-Path $log 'preflight.json')
$stageSucceeded=$false
try {
 foreach($name in @('Root','TrustedPublisher')){
  $store=[Security.Cryptography.X509Certificates.X509Store]::new($name,[Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
  try{$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite);$store.Add($cert)}finally{$store.Close()}
 }
 $inf=Join-Path $script:TaskRoot 'outputs/Mac1905-driver/pakke/macmini_restore_1905.inf'
 & (Join-Path $env:windir 'System32/pnputil.exe') /add-driver $inf 2>&1 | Tee-Object -FilePath (Join-Path $log 'pnputil.txt')
 $code=$LASTEXITCODE
 $after=@(Get-WindowsDriver -Online -All)
 $after | Select-Object Driver,OriginalFileName,ProviderName,Version | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 (Join-Path $log 'driver-after.json')
 $matching=@($after | Where-Object {[IO.Path]::GetFileName($_.OriginalFileName)-ieq'macmini_restore_1905.inf'})
 if($code-ne0 -or $matching.Count-ne1){throw "Cannot continue without successful staging and no reboot requirement; exit=$code"}
 $published=$matching[0].Driver
 if((Get-FileHash -LiteralPath (Join-Path $env:windir "INF/$published") -Algorithm SHA256).Hash-ne$script:TaskInfHash){throw 'Published INF hash mismatch.'}
 if(@($before | Where-Object {$_.Driver-notin@($after.Driver)}).Count){throw 'Existing package inventory decreased.'}
 foreach($name in $protected.Keys){if((Get-FileHash -LiteralPath (Join-Path $env:windir "INF/$name") -Algorithm SHA256).Hash-ne$protected[$name]){throw "Protected Apple INF changed: $name"}}
 if(Test-TaskKeyExists){throw 'Unexpected signing private key appeared.'}
 [ordered]@{PublishedName=$published;OriginalName='macmini_restore_1905.inf';InfSha256=$script:TaskInfHash;ExitCode=$code;StagedOnly=$true;InstallSwitchUsed=$false;PrivateKeyExists=$false;TrustTemporarilyAddedTo=@('LocalMachine/Root','LocalMachine/TrustedPublisher');CleanupRequiredAfterSuccessFailureOrCancellation=$true} | ConvertTo-Json | Tee-Object -FilePath (Join-Path $log 'result.json')
 $stageSucceeded=$true
} finally {
 if(-not$stageSucceeded){& (Join-Path $PSScriptRoot 'cleanup-mac1905-temporary.ps1') -ApplyAfterUserApproval}
 $cert.Dispose()
}
