param([Parameter(Mandatory=$true)][ValidateRange(1,3)][int]$Replica)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$exe=Join-Path $root 'bin\windows-x64\restorekit.exe'
$expectedHash='B59206BC8E7046FF696A87DF029BD919BCD6659E06E82D11DD940F67126D2F93'
if((Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash -ine $expectedHash){throw 'Built main SHA256 differs from reviewed executable'}
if(@(Get-CimInstance Win32_Process | Where-Object Name -eq 'restorekit.exe').Count){throw 'Another restorekit process exists; no check started'}
if(@(Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object InstanceId -match '^(USB|KIS)\\VID_05AC').Count){throw 'Apple USB/KIS device present; this no-hardware check is prohibited'}
$before=@(Get-NetTCPConnection -State Listen -LocalPort 27015,27016 -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess)
if(@($before | Where-Object LocalPort -eq 27016).Count){throw 'Private port27016 occupied; no check started'}
$dir=Join-Path $root 'cloud-smoke-results'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$out=Join-Path $dir 'stdout.log';$err=Join-Path $dir 'stderr.log'
$child=$null;$childHandle=[IntPtr]::Zero;$timedOut=$false;$completed=$false
$watch=[Diagnostics.Stopwatch]::StartNew()
$previousMux=[Environment]::GetEnvironmentVariable('USBMUXD_SOCKET_ADDRESS','Process')
$inheritedMux=switch($Replica){1{$null}2{'127.0.0.1:27015'}3{'127.0.0.1:1'}}
try {
    # Deliberately challenge the native CRT snapshot. The fixed C connector
    # must use private27016 even if the child inherits Apple or a closed port.
    [Environment]::SetEnvironmentVariable('USBMUXD_SOCKET_ADDRESS',$inheritedMux,'Process')
    # This is the only executable command: no restore/setup-driver or ops script.
    $child=Start-Process -FilePath $exe -ArgumentList '--json','check-usb' -WorkingDirectory (Split-Path $exe) -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err -PassThru
    $childHandle=$child.Handle
    Write-Output ('Own no-device child PID='+$child.Id+' replica='+$Replica)
    if(-not $child.WaitForExit(30000)){$timedOut=$true;throw 'Own check-usb exceeded30second runtime limit'}
    $child.WaitForExit();$child.Refresh()
    if($child.ExitCode -ne 0){throw ('Own check-usb exit='+$child.ExitCode)}
    $events=@(Get-Content -LiteralPath $out | ForEach-Object {try{$_ | ConvertFrom-Json -ErrorAction Stop}catch{}})
    $passed=@($events | Where-Object {$_.event -eq 'usb_check_passed' -and $_.endpoint -eq '127.0.0.1:27016' -and $_.firmware_uploaded -eq $false -and $_.data_erased -eq $false})
    if($passed.Count -ne 1){throw 'Expected exact private protocol/teardown success event missing'}
    $after=@(Get-NetTCPConnection -State Listen -LocalPort 27015,27016 -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess)
    if(@($after | Where-Object LocalPort -eq 27016).Count){throw 'Private listener27016 remains after child exit'}
    $appleBefore=@($before | Where-Object LocalPort -eq 27015 | ForEach-Object {"$($_.LocalAddress):$($_.OwningProcess)"} | Sort-Object)
    $appleAfter=@($after | Where-Object LocalPort -eq 27015 | ForEach-Object {"$($_.LocalAddress):$($_.OwningProcess)"} | Sort-Object)
    if(($appleBefore -join '|') -cne ($appleAfter -join '|')){throw 'Existing Apple27015listener changed during check'}
    $result=[ordered]@{Replica=$Replica;SHA256=$expectedHash;ExitCode=$child.ExitCode;Seconds=[math]::Round($watch.Elapsed.TotalSeconds,2);NoAppleDevicePresent=$true;Private27016Gone=$true;Apple27015Unchanged=$true;Scope='Actual reviewed Windows main executable: local private mux startup/ListDevices/teardown only. No physical Mac transport or restore claim.';DriverChanged=$false;CertificateChanged=$false;FirmwareUploaded=$false;DataErased=$false}
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $dir 'result.json') -Encoding UTF8
    [ordered]@{NativeCClientVerified=$true;InheritedMux=$inheritedMux;PrivateEndpoint='127.0.0.1:27016';Scope='Actual C ListDevices request must be accepted by the private server; Rust-only TCP success is insufficient'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dir 'native-routing.json') -Encoding UTF8
    $result | ConvertTo-Json -Depth 5 | Write-Output
    $completed=$true
} finally {
    [Environment]::SetEnvironmentVariable('USBMUXD_SOCKET_ADDRESS',$previousMux,'Process')
    if($child -and -not $child.HasExited){
        # Kill only the exact retained Process object created by this invocation.
        $child.Kill();[void]$child.WaitForExit(5000)
    }
    $watch.Stop()
    if($timedOut){'Only this invocation own check-usb process was stopped.' | Set-Content -LiteralPath (Join-Path $dir 'timeout.txt')}
    if(-not $completed){'Check failed; inspect child stdout/stderr. No restore or setup-driver command ran.' | Set-Content -LiteralPath (Join-Path $dir 'failure.txt')}
    if(Test-Path -LiteralPath $out){Get-Content -LiteralPath $out | Write-Output}
    if(Test-Path -LiteralPath $err){Get-Content -LiteralPath $err | Write-Output}
}


