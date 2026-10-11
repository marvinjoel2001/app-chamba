param(
    [Parameter(Mandatory)][ValidateSet('emulator-5554', 'emulator-5556')][string]$Device,
    [Parameter(Mandatory)][ValidateSet('capture', 'tap', 'type', 'back', 'swipe')][string]$Action,
    [int]$X = 0, [int]$Y = 0, [int]$EndX = 0, [int]$EndY = 0,
    [string]$Text = '', [string]$Output = ''
)
$ErrorActionPreference = 'Stop'
$taskAdb = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
if ($Action -eq 'capture') {
    if (!$Output) { $Output = Join-Path $env:TEMP ('chamba-qa-' + $Device + '.png') }
    $taskInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $taskInfo.FileName = $taskAdb
    $taskInfo.UseShellExecute = $false
    $taskInfo.RedirectStandardOutput = $true
    $taskInfo.CreateNoWindow = $true
    foreach ($taskArg in @('-s', $Device, 'exec-out', 'screencap', '-p')) {
        $taskInfo.ArgumentList.Add($taskArg)
    }
    $taskProcess = [System.Diagnostics.Process]::Start($taskInfo)
    $taskFile = [System.IO.File]::Create($Output)
    try { $taskProcess.StandardOutput.BaseStream.CopyTo($taskFile) }
    finally { $taskFile.Dispose() }
    $taskProcess.WaitForExit()
    if ($taskProcess.ExitCode -ne 0) { throw 'ADB capture failed' }
    Write-Output $Output
    exit
}
switch ($Action) {
    'tap' { & $taskAdb -s $Device shell input tap $X $Y }
    'type' { & $taskAdb -s $Device shell input text $Text.Replace(' ', '%s') }
    'back' { & $taskAdb -s $Device shell input keyevent 4 }
    'swipe' { & $taskAdb -s $Device shell input swipe $X $Y $EndX $EndY 450 }
}
if ($LASTEXITCODE -ne 0) { throw 'ADB input failed' }
Start-Sleep -Milliseconds 400
& $PSCommandPath -Device $Device -Action capture
