param(
 [Parameter(Mandatory=$true)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedHash,
 [Parameter(Mandatory=$true)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedAppleMuxHash
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root
$tag = 'attempt8-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)
$stdout = Join-Path $PSScriptRoot ($tag + '-stdout.log')
$stderr = Join-Path $PSScriptRoot ($tag + '-stderr.log')
$audit = Join-Path $PSScriptRoot ($tag + '-supervisor.log')
$statusFile = Join-Path $PSScriptRoot 'restore-apple-attempt8-status.txt'
$exe = Join-Path $PSScriptRoot 'restorekit-source\target\x86_64-pc-windows-gnu\release\restorekit.exe'
$expectedExeHash = $ExpectedHash
$restore1905InfHash = '96900A82E846BDE1999787C566D8B22DC52D108545B9E76FCAA4DA2F79334E02'
$restore1905Published = $null
$appleInfHashes = @{
 'oem147.inf'='71EF7DBEF3E7B2C1BDC32C1A4400AA5F92C5C7EEE9EF6261385C54CD9D0E26A6'
 'oem178.inf'='B385F6D5839E6A031451947F8CE57A361B2866BA888BEA58CE37F425D36C020E'
 'oem91.inf'='10AAC2D96E5B2C8F55605FD6ACF6A39C7EF3D092018A5BC622011EC46C139A7C'
} # Read-only INF SHA256 snapshot taken during preparation; no trust validation.
$appleListenersBefore = @()
$nativeActive = $false
$ipsw = Join-Path $PSScriptRoot 'firmware\UniversalMac_15.6.1_24G90_Restore.ipsw'
$cache = Join-Path $PSScriptRoot 'firmware'
$locationPrefix = 'PCIROOT(0)#PCI(1400)#USBROOT(0)#USB(13)'
$controllerEcid = '165715DA257CBD11'
$native = $null; $nativeHandle = [IntPtr]::Zero; $exitCode = 1; $awake = $false
$lastBindingReport = ''
function Status([string]$message) {
    $line = (Get-Date -Format o) + ' ' + $message
    Add-Content -LiteralPath $audit -Value $line
    Set-Content -LiteralPath $statusFile -Value $line
    Write-Output $line
}
function Target-Location([string]$instance) {
    $paths = @((Get-PnpDeviceProperty -InstanceId $instance -KeyName DEVPKEY_Device_LocationPaths -ErrorAction Stop).Data)
    foreach ($path in $paths) {
        if ($path -eq $locationPrefix -or $path.StartsWith($locationPrefix + '#',[StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}
function Conflicting-Processes {
    # Exclude only self and the verified current parent chain, including an outer launcher.
    $snapshot = @(Get-CimInstance Win32_Process)
    $index = @{}
    foreach ($process in $snapshot) { $index[[uint32]$process.ProcessId] = $process }
    $ancestors = @{}
    $cursor = [uint32]$PID
    for ($depth=0; $depth -lt 64; $depth++) {
        if ($ancestors.ContainsKey($cursor) -or -not $index.ContainsKey($cursor)) { break }
        $ancestors[$cursor] = $true
        $child = $index[$cursor]
        $parentId = [uint32]$child.ParentProcessId
        if ($parentId -eq 0 -or -not $index.ContainsKey($parentId)) { break }
        $parent = $index[$parentId]
        # A newer PID owner is not the process that originally launched this child.
        if (-not $parent.CreationDate -or -not $child.CreationDate -or $parent.CreationDate -gt $child.CreationDate) { break }
        $cursor = $parentId
    }
    @($snapshot | Where-Object {
        -not $ancestors.ContainsKey([uint32]$_.ProcessId) -and (
            $_.Name -ieq 'restorekit.exe' -or
            ($_.Name -match '^(powershell|pwsh)\.exe$' -and $_.CommandLine -match '(?i)--rk-bind|restorekit-restore-watch|(?:^|[\\/"\s])restore-live\.ps1(?:["\s]|$)|(?:^|[\\/"\s])restore-supervisor\.ps1(?:["\s]|$)|(?:^|[\\/"\s])restore-apple-attempt\d+\.ps1(?:["\s]|$)')
        )
    })
}
function Target-ThroughParentChain([string]$instance) {
    $seen = @{}
    for ($depth=0; $depth -lt 16 -and $instance; $depth++) {
        if ($seen.ContainsKey($instance)) { return $false }
        $seen[$instance] = $true
        if ($instance -match '^USB\\VID_05AC&PID_') { return (Target-Location $instance) }
        $instance = (Get-PnpDeviceProperty -InstanceId $instance -KeyName DEVPKEY_Device_Parent -ErrorAction Stop).Data
    }
    return $false
}
function Verify-StagedAppleDriver([string]$publishedInf,[string]$originalInf,[string]$hardwarePattern,[string[]]$requiredFiles) {
    $published = Join-Path $env:windir ('INF\' + $publishedInf)
    if (-not (Test-Path -LiteralPath $published -PathType Leaf)) { throw "Missing staged driver INF $publishedInf" }
    $content = Get-Content -LiteralPath $published -Raw
    $activeLines = ($content -split "`r?`n" | Where-Object { $_ -notmatch '^\s*;' }) -join "`n"
    if ($activeLines -notmatch $hardwarePattern) { throw "$publishedInf does not actively match required Apple hardware" }
    $publishedHash = (Get-FileHash -LiteralPath $published -Algorithm SHA256).Hash
    $repository = Join-Path $env:windir 'System32\DriverStore\FileRepository'
    $matches = @(Get-ChildItem -LiteralPath $repository -Directory | Where-Object { $_.Name -like ($originalInf + '_amd64_*') } | Where-Object {
        $candidate = Join-Path $_.FullName $originalInf
        (Test-Path -LiteralPath $candidate -PathType Leaf) -and (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -eq $publishedHash
    })
    if ($matches.Count -ne 1) { throw "Expected exactly one matching DriverStore package for $publishedInf" }
    foreach ($file in $requiredFiles) {
        $binary = Join-Path $matches[0].FullName $file
        if (-not (Test-Path -LiteralPath $binary -PathType Leaf) -or (Get-Item -LiteralPath $binary).Length -eq 0) { throw "Missing staged driver component $binary" }
    }
    Status "Staged Apple driver verified $publishedInf package=$($matches[0].FullName); first normal PnP initialization remains untested"
}
function Binding-Report {
    $rows = @()
    foreach ($device in @(Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match '^USB\\VID_05AC&PID_' })) {
        try {
            if (-not (Target-Location $device.InstanceId)) { $rows += "UNEXPECTED Apple outside target: $($device.InstanceId)"; continue }
            $driver = (Get-PnpDeviceProperty -InstanceId $device.InstanceId -KeyName DEVPKEY_Device_DriverInfPath -ErrorAction Stop).Data
            $flag = ''
            $expectedDriver = if ($device.InstanceId -match 'PID_1905') { $restore1905Published } elseif ($device.InstanceId -match 'PID_1881') { 'oem178.inf' } else { 'oem147.inf' }
            if ($driver -ine $expectedDriver) { $flag += " UNEXPECTED_DRIVER expected=$expectedDriver" }
            $rows += "$($device.InstanceId) driver=$driver$flag"
        } catch { $rows += "Transitioning node: $($device.InstanceId) ($($_.Exception.Message))" }
    }
    foreach ($device in @(Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match '^KIS\\VID_05AC&PID_0001\\' })) {
        try {
            if (-not (Target-ThroughParentChain $device.InstanceId)) { $rows += "Unverified KIS parent chain: $($device.InstanceId)"; continue }
            $driver = (Get-PnpDeviceProperty -InstanceId $device.InstanceId -KeyName DEVPKEY_Device_DriverInfPath -ErrorAction Stop).Data
            $flag = if ($driver -ine 'oem91.inf') { ' UNEXPECTED_DRIVER expected=oem91.inf' } else { '' }
            $rows += "KIS target child $($device.InstanceId) driver=$driver$flag"
        } catch { $rows += "Transitioning KIS child: $($device.InstanceId) ($($_.Exception.Message))" }
    }
    if (-not $rows.Count) { return 'No Apple USB node currently present' }
    return ($rows -join ' | ')
}
Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public static class RestoreAppleAttempt8Awake {
 [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags);
}
'@
try {
    Status 'Read-only preflight: one restore; Apple DFU/KIS/recovery and private PID1905 mux; no install/rebind/trust changes'
    # Read-only inventory; staging/install approval occurs separately.
    $driverInventory = @(Get-WindowsDriver -Online -All -ErrorAction Stop)
    if (@($driverInventory | Where-Object { [IO.Path]::GetFileName($_.OriginalFileName) -ieq 'restorekit_winusb.inf' }).Count) { throw 'Original broad RestoreKit WinUSB package remains installed' }
    $restorePackages = @($driverInventory | Where-Object { [IO.Path]::GetFileName($_.OriginalFileName) -ieq 'macmini_restore_1905.inf' })
    if ($restorePackages.Count -ne 1) { throw 'Expected exactly one separately approved/staged PID1905 package; nothing will be installed by this script' }
    $restore1905Published = [IO.Path]::GetFileName($restorePackages[0].Driver)
    if ($restore1905Published -notmatch '^oem[0-9]+\.inf$') { throw 'Invalid published OEM name for PID1905 package' }
    $restorePublishedPath = Join-Path $env:windir ('INF\' + $restore1905Published)
    if ((Get-FileHash -LiteralPath $restorePublishedPath -Algorithm SHA256).Hash -ine $restore1905InfHash -or (Get-FileHash -LiteralPath $restorePackages[0].OriginalFileName -Algorithm SHA256).Hash -ine $restore1905InfHash) { throw 'Staged PID1905 INF does not match reviewed exact package' }
    foreach ($inf in $appleInfHashes.Keys) {
        if ((Get-FileHash -LiteralPath (Join-Path $env:windir ('INF\' + $inf)) -Algorithm SHA256).Hash -ine $appleInfHashes[$inf]) { throw "Apple INF changed: $inf" }
    }
    if (@(Get-NetTCPConnection -State Listen -LocalPort 27016 -ErrorAction SilentlyContinue).Count) { throw 'Private port27016 already in use' }
    Status "Separate PID1905 package verified original=macmini_restore_1905.inf published=$restore1905Published SHA256=$restore1905InfHash; no driver/trust changes performed"
    foreach ($path in @($exe,$ipsw)) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing required file: $path" } }
    if ((Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash -ne $expectedExeHash) { throw 'Native executable hash changed; review required' }
    if ((Get-Item -LiteralPath $ipsw).Length -ne 16814137790) { throw 'Unexpected IPSW size' }
    Verify-StagedAppleDriver 'oem178.inf' 'applekis.inf' '(?im)^\s*[^;\r\n]*=\s*AppleKIS_Device,\s*USB\\VID_05AC&PID_1881\s*$' @('AppleKIS.sys','AppleKISInterface.dll','AppleKIS.cat')
    Verify-StagedAppleDriver 'oem91.inf' 'applersm.inf' '(?im)^\s*[^;\r\n]*=\s*AppleRSM_Device,\s*KIS\\VID_05AC&PID_0001\s*$' @('AppleRSM.sys','AppleRSMInterface.dll','AppleRSM.cat')
    $conflicts = @(Conflicting-Processes)
    if ($conflicts.Count) { throw ('Conflicting restore/watcher processes: ' + (($conflicts | ForEach-Object { "$($_.ProcessId):$($_.Name) $($_.CommandLine)" }) -join ' | ')) }
    $appleDevices = @(Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match '^USB\\VID_05AC&PID_' })
    if (-not $appleDevices.Count) { throw 'No Apple USB device present' }
    foreach ($device in $appleDevices) {
        if (-not (Target-Location $device.InstanceId)) { throw "Apple USB node outside authorized physical port: $($device.InstanceId)" }
        $driver = (Get-PnpDeviceProperty -InstanceId $device.InstanceId -KeyName DEVPKEY_Device_DriverInfPath -ErrorAction Stop).Data
        if ($driver -ine 'oem147.inf') { throw "Expected Apple oem147.inf: $($device.InstanceId) uses $driver" }
    }
    $parents = @($appleDevices | Where-Object { $_.InstanceId -notmatch '&MI_[0-9A-F]{2}\\' })
    if ($parents.Count -ne 1) { throw "Expected sole Apple parent; found $($parents.Count)" }
    $controller = $parents[0].InstanceId
    if ($controller -notmatch '^USB\\VID_05AC&PID_F014\\') { throw 'Expected F014 PortDFU parent' }
    if ($controller -notmatch '(?:\\|_)ECID:165715DA257CBD11(?:_|$)' -or $controller -notmatch '(?:\\|_)CPID:0*0022(?:_|$)' -or $controller -notmatch '(?:\\|_)BDID:0*2A813200(?:_|$)') { throw 'Controller ECID/CPID/packed BDID does not match expected M4' }
    $raw = & $exe --json list
    if ($LASTEXITCODE -ne 0) { throw 'Native device listing failed' }
    $devices = @( (($raw -join "`n") | ConvertFrom-Json).devices )
    if ($devices.Count -ne 1) { throw 'Native list must contain exactly one Apple device' }
    if ($devices[0].identity.model.identifier -ne 'Mac16,10' -or $devices[0].mode -ne 'dfu' -or ('0x{0:x}' -f [UInt64]$devices[0].ecid) -ne '0x165715da257cbd11') { throw 'Native list identity/model/mode mismatch' }
    $listeners = @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort 27015 -ErrorAction Stop)
    $owners = @($listeners.OwningProcess | Select-Object -Unique)
    if ($owners.Count -ne 1) { throw 'Expected a single Apple usbmux listener owner at127.0.0.1:27015' }
    $owner = Get-CimInstance Win32_Process -Filter "ProcessId=$($owners[0])"
    if ($owner.Name -ine 'AppleMobileDeviceProcess.exe' -or -not $owner.ExecutablePath) { throw 'usbmux listener is not AppleMobileDeviceProcess.exe' }
    $packages = @(Get-AppxPackage -AllUsers -Name AppleInc.AppleDevices)
    $installed = $false
    foreach ($package in $packages) {
        if ($package.InstallLocation -and $owner.ExecutablePath.StartsWith($package.InstallLocation.TrimEnd('\') + '\',[StringComparison]::OrdinalIgnoreCase)) { $installed = $true }
    }
    if (-not $installed) { throw 'usbmux executable is outside installed AppleDevices packages' }
    if ((Get-FileHash -LiteralPath $owner.ExecutablePath -Algorithm SHA256).Hash -ine $ExpectedAppleMuxHash) { throw 'Apple usbmux executable hash differs from reviewed installed-package binary' }
    $appleListenersBefore = @($listeners | ForEach-Object { "$($_.LocalAddress):$($_.OwningProcess)" })
    Status "Preflight passed controller=$controller; nativeSHA256=$expectedExeHash; AppleusbmuxPID=$($owner.ProcessId) path=$($owner.ExecutablePath) SHA256=$ExpectedAppleMuxHash; privateEndpoint=127.0.0.1:27016"
    # Remove inherited route overrides; reviewed native sets private mux itself.
    Remove-Item Env:RESTOREKIT_SHARED_USBMUXD -ErrorAction SilentlyContinue
    Remove-Item Env:USBMUXD_SOCKET_ADDRESS -ErrorAction SilentlyContinue
    if ([RestoreAppleAttempt8Awake]::SetThreadExecutionState(2147483649) -eq 0) { throw 'Could not prevent sleep' }
    $awake = $true
    $arguments = '--verbose restore --ipsw "' + $ipsw + '" --ecid 0x165715da257cbd11 --yes --cache-dir "' + $cache + '"'
    $native = Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    $nativeHandle = $native.Handle # Retain handle before an early process exit.
    Status "Single restore started PID=$($native.Id); stdout=$stdout; stderr=$stderr"
    while (-not $native.HasExited) {
        try {
            $report = Binding-Report
            if ($report -ne $lastBindingReport) { Status "USB phase: $report"; $lastBindingReport = $report }
        } catch { Status ('Read-only USB status unavailable: ' + $_.Exception.Message) }
        if (-not $native.HasExited) { [void]$native.WaitForExit(3000) }
        $native.Refresh()
    }
    $native.WaitForExit()
    $native.Refresh()
    $exitCode = $native.ExitCode
    Status "Restore exited code=$exitCode. No automatic retries or driver changes performed."
} catch {
    Status ('Attempt8 supervisor error: ' + $_.Exception.Message)
    if ($native) {
        $native.Refresh()
        if (-not $native.HasExited) { Status "MANUAL MONITOR REQUIRED native PID=$($native.Id) remains active; stdout=$stdout; stderr=$stderr" }
    }
    $exitCode = 1
} finally {
    if ($native) {
        try { $native.Refresh(); $nativeActive = -not $native.HasExited } catch { $nativeActive = $true }
    }
    if ($nativeActive) {
        Status "ACTIVE_RESTORE PID=$($native.Id): no process stop, no driver/certificate/trust cleanup; retain monitoring until native exits"
    } else {
        if (@(Get-NetTCPConnection -State Listen -LocalPort 27016 -ErrorAction SilentlyContinue).Count) {
            Status 'ERROR: private listener27016 remains after own native exited; no unrelated process will be stopped'
            $exitCode = 1
        } else { Status 'Private listener27016 absent after own native exit (or preflight failure)' }
        if ($awake) { [void][RestoreAppleAttempt8Awake]::SetThreadExecutionState(2147483648) }
    }
    if ($appleListenersBefore.Count) {
        $appleListenersAfter = @(Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort 27015 -ErrorAction SilentlyContinue | ForEach-Object { "$($_.LocalAddress):$($_.OwningProcess)" })
        if ((($appleListenersBefore | Sort-Object) -join "|") -cne (($appleListenersAfter | Sort-Object) -join "|")) { Status 'ERROR: Apple listener27015 owner/address changed; no action taken'; $exitCode=1 }
        else { Status 'Apple listener27015 owner/address unchanged' }
    }
    try {
        $leftovers = @(Conflicting-Processes)
        Status ('Restore/watcher process leftovers (read-only): ' + (($leftovers | ForEach-Object { "$($_.ProcessId):$($_.Name) $($_.CommandLine)" }) -join ' | '))
    } catch { Status ('Could not enumerate leftovers: ' + $_.Exception.Message) }
    if ($nativeActive) { Status "Supervisor returned with active native PID=$($native.Id); restore outcome unconfirmed; logs=$tag" } else { Status "Supervisor finished exit=$exitCode; logs retained under $tag" }
}
exit $exitCode


