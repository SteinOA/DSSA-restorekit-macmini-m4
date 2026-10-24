param([Parameter(Mandatory=$true)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedHash)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root
$exe=Join-Path $root 'work\restorekit-source\target\x86_64-pc-windows-gnu\release\restorekit.exe'
if((Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash -ine $ExpectedHash){throw 'Main executable hash mismatch'}
if(@(Get-CimInstance Win32_Process | Where-Object Name -eq 'restorekit.exe').Count){throw 'Another restorekit process is present; no test started'}
$devices=@(Get-PnpDevice -PresentOnly | Where-Object InstanceId -match '^(USB|KIS)\\VID_05AC')
if($devices.Count){throw 'An Apple USB device is present; this no-device test was not started'}
$before=@(Get-NetTCPConnection -State Listen -LocalPort 27015,27016 -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess)
if(@($before | Where-Object LocalPort -eq 27016).Count){throw 'Private port already in use; no test started'}
$tag=Get-Date -Format 'yyyyMMdd-HHmmss'
$dir=Join-Path $root ('outputs\USB-lesetest\'+$tag)
New-Item -ItemType Directory -Path $dir -ErrorAction Stop | Out-Null
$out=Join-Path $dir 'stdout.log'
$err=Join-Path $dir 'stderr.log'
$test=$null
$timedOut=$false
$observed=@()
$watch=[System.Diagnostics.Stopwatch]::StartNew()
try {
    $test=Start-Process -FilePath $exe -ArgumentList '--json','check-usb' -WorkingDirectory (Split-Path $exe) -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err -PassThru
    Write-Output ('Own check-usb process: '+$test.Id)
    while(-not $test.WaitForExit(100)){
        $observed+=@(Get-NetTCPConnection -State Listen -LocalPort 27016 -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess)
        if($watch.Elapsed.TotalSeconds -gt 30){$timedOut=$true; throw 'Own USB check did not finish within 30 seconds'}
    }
    $test.WaitForExit()
    if($test.ExitCode -ne 0){throw ('USB check failed with exit code '+$test.ExitCode)}
    $log=Get-Content -LiteralPath $out -Raw
    if($log -notmatch '"event":"usb_check_passed"'){throw 'Expected protocol/teardown success event missing'}
    $after=@(Get-NetTCPConnection -State Listen -LocalPort 27015,27016 -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess)
    if(@($after | Where-Object LocalPort -eq 27016).Count){throw 'Private listener still present after check exit'}
    $appleBefore=@($before | Where-Object LocalPort -eq 27015 | ForEach-Object {"$($_.LocalAddress):$($_.OwningProcess)"})
    $appleAfter=@($after | Where-Object LocalPort -eq 27015 | ForEach-Object {"$($_.LocalAddress):$($_.OwningProcess)"})
    if(@(Compare-Object $appleBefore $appleAfter).Count){throw 'Apple listener changed during test'}
    $result=[ordered]@{Time=(Get-Date -Format o);Executable=$exe;SHA256=$ExpectedHash.ToUpperInvariant();ExitCode=$test.ExitCode;Seconds=[math]::Round($watch.Elapsed.TotalSeconds,2);NoAppleDevicePresentAtStart=$true;AppleListenerUnchanged=$true;PrivateListenerGone=$true;ObservedPrivateListeners=$observed;ListenersBefore=$before;ListenersAfter=$after;Scope='Local service startup, ListDevices protocol and teardown only; does not prove transport to Mac';DriverChanged=$false;CertificateChanged=$false;FirmwareUploaded=$false;DataErased=$false}
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $dir 'resultat.json') -Encoding UTF8
    $result | ConvertTo-Json -Depth 6 | Write-Output
    Get-Content -LiteralPath $out
    Get-Content -LiteralPath $err
} finally {
    if($test -and -not $test.HasExited){
        # This Process object holds only the exact child created for this test.
        $test.Kill()
        $test.WaitForExit(5000) | Out-Null
    }
    $watch.Stop()
    if($timedOut){'Only the process created by this test was stopped.' | Set-Content -LiteralPath (Join-Path $dir 'timeout.txt')}
}
