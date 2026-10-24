# Shared, task-scoped helpers. No chain building or signature-policy checks.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:TaskThumb='4AB0DB3E9B0D6D055133E286B3D16F3460FBFB31'
$script:TaskKey='te-6087c5f9-045d-456f-935e-20cc89e024a0'
$script:TaskInfHash='96900A82E846BDE1999787C566D8B22DC52D108545B9E76FCAA4DA2F79334E02'
$script:TaskCatHash='6597FB9FC3F12FF4BA5B99154AEEEBA79CFB716A701DAFAB689DDBAE835DD3CB'
$script:TaskRoot=Split-Path -Parent $PSScriptRoot
function Require-TaskAdmin {
 $p=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
 if(-not$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Administrator PowerShell required for an approved system change.'}
}
function Read-TaskPublicCertificate {
 if(-not ('System.Security.Cryptography.Pkcs.SignedCms' -as [type])){Add-Type -AssemblyName System.Security -ErrorAction Stop}
 $folder=Join-Path $script:TaskRoot 'outputs/Mac1905-driver/pakke'
 $inf=Join-Path $folder 'macmini_restore_1905.inf';$cat=Join-Path $folder 'macmini_restore_1905.cat'
 if(@(Get-ChildItem -LiteralPath $folder -Force).Count-ne2){throw 'Reviewed package must contain exactly two files.'}
 if((Get-FileHash -LiteralPath $inf -Algorithm SHA256).Hash-ne$script:TaskInfHash -or (Get-FileHash -LiteralPath $cat -Algorithm SHA256).Hash-ne$script:TaskCatHash){throw 'Reviewed package hash mismatch.'}
 $cms=[Security.Cryptography.Pkcs.SignedCms]::new();$cms.Decode([IO.File]::ReadAllBytes($cat))
 $certs=@($cms.Certificates | Where-Object Thumbprint -eq $script:TaskThumb)
 if($certs.Count-ne1 -or $certs[0].HasPrivateKey -or $certs[0].Subject-ne'CN=RestoreKit WinUSB'){throw 'Expected exact public-only certificate missing from signed CAT.'}
 if([DateTime]::Now-lt$certs[0].NotBefore -or [DateTime]::Now-gt$certs[0].NotAfter){throw 'Historical certificate is outside its date interval.'}
 return $certs[0]
}
function Find-TaskCertificates {
 @(foreach($scope in @('Cert:/LocalMachine','Cert:/CurrentUser')){
  Get-ChildItem $scope -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSObject.Properties['Thumbprint'] -and $_.Thumbprint-eq$script:TaskThumb } | ForEach-Object {
   $match=[regex]::Match($_.PSPath,'Certificate::((?:CurrentUser|LocalMachine)\\[^\\]+)\\([A-Fa-f0-9]{40})$')
   if(-not$match.Success){throw 'Unexpected certificate provider path.'}
   [pscustomobject]@{Path=('Cert:\'+$match.Groups[1].Value+'\'+$match.Groups[2].Value);HasPrivateKey=$_.HasPrivateKey;Subject=$_.Subject}
  }
 })
}
function Test-TaskKeyExists {
 [Security.Cryptography.CngKey]::Exists($script:TaskKey,[Security.Cryptography.CngProvider]::new('Microsoft Software Key Storage Provider'),[Security.Cryptography.CngKeyOpenOptions]::None)
}
function Get-TaskDriverPackages {
 @(Get-WindowsDriver -Online -All | Where-Object {[IO.Path]::GetFileName($_.OriginalFileName)-ieq'macmini_restore_1905.inf'})
}
function Assert-NoTaskRestore {
 $workspace=[IO.Path]::GetFullPath($script:TaskRoot).TrimEnd('\')
 $processes=@(Get-CimInstance Win32_Process)
 $active=@($processes | Where-Object {
  if($_.ProcessId-eq$PID){return $false}
  $exe=[string]$_.ExecutablePath;$cmd=[string]$_.CommandLine
  $inWorkspace=($exe.StartsWith($workspace+'\',[StringComparison]::OrdinalIgnoreCase) -or $cmd.IndexOf($workspace,[StringComparison]::OrdinalIgnoreCase)-ge0)
  if(-not$inWorkspace){return $false}
  if($_.Name-ieq'restorekit.exe'){return $true}
  if($_.Name-notmatch'^(pwsh|powershell)\.exe$'){return $false}
  return $cmd-match'(?i)--rk-bind-restore-mode|restore-apple-attempt[0-9]+(?:\.ps1)?|reset-exact-mac-port\.ps1|supervise-restore[^"\s]*\.ps1|supervisor-attempt[^"\s]*\.ps1'
 })
 if($active.Count){throw 'An active restore or known watcher for THIS workspace is still running.'}
}

