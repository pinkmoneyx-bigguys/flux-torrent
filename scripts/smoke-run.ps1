# Starts the app with a throwaway dev profile and checks that it is alive with a responsive main window.
param(
    [Parameter(Mandatory = $true)] [string]$Exe,
    [int]$Seconds = 10
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$profileDir = Join-Path $repo '.devprofile'
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null

$exePath = (Resolve-Path $Exe).Path
$proc = Start-Process -FilePath $exePath -ArgumentList "--profile=`"$profileDir`"" -PassThru
Start-Sleep -Seconds $Seconds
$proc.Refresh()

$ok = $true
if ($proc.HasExited) {
    Write-Output "FAIL: process exited early with code $($proc.ExitCode)"
    $ok = $false
} else {
    if ($proc.MainWindowHandle -eq 0) { Write-Output 'FAIL: no main window'; $ok = $false }
    elseif (-not $proc.Responding) { Write-Output 'FAIL: window not responding'; $ok = $false }
    else { Write-Output "OK: '$($proc.MainWindowTitle)' is up and responding" }
    [void]$proc.CloseMainWindow()
    if (-not $proc.WaitForExit(15000)) { Stop-Process -Id $proc.Id -Force }
}
if ($ok) { exit 0 } else { exit 1 }
