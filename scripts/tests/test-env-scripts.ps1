# Regression tests for the environment scripts. Run: powershell -ExecutionPolicy Bypass -File scripts\tests\test-env-scripts.ps1
# Each test runs in a fresh child PowerShell so session PATH changes do not leak between tests.
$ErrorActionPreference = 'Stop'
$common = (Resolve-Path (Join-Path $PSScriptRoot '..\common.ps1')).Path

function Invoke-Isolated([string]$body) {
    $script = ". '$common'`n$body"
    $ErrorActionPreference = 'Continue'  # child stderr (e.g. VsDevCmd noise) must not abort the runner
    $out = powershell -NoProfile -ExecutionPolicy Bypass -Command $script 2>&1 | Out-String
    [pscustomobject]@{ Ok = ($LASTEXITCODE -eq 0); Output = $out.Trim() }
}

$tests = [ordered]@{
    'UserPathHasNoPython313' = {
        $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
        $raw = $k.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $bad = @($raw -split ';' | Where-Object { $_ -match 'Python313' })
        if ($bad.Count) { "user PATH still lists: $($bad -join ', ')" }
    }
    'UserPathIsExpandString' = {
        $kind = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment').GetValueKind('Path')
        if ($kind -ne 'ExpandString') { "user PATH value kind is $kind" }
    }
    'PyDefaultsTo310' = {
        $v = (cmd /c 'py --version 2>&1' | Out-String).Trim()
        if ($v -notlike 'Python 3.10*') { "bare py starts '$v'" }
    }
    'DevShellSurvivesPathRefresh' = {
        $r = Invoke-Isolated "Enter-FluxDevShell; Update-SessionPath; Enter-FluxDevShell; if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) { Write-Output 'cl.exe lost'; exit 1 }"
        if (-not $r.Ok) { $r.Output }
    }
    'ToolsFoundWithoutUserPath' = {
        $r = Invoke-Isolated "Update-SessionPath; foreach (`$t in 'cmake','ninja') { if (-not (Get-Command `$t -ErrorAction SilentlyContinue)) { Write-Output `"`$t not found`"; exit 1 } }"
        if (-not $r.Ok) { $r.Output }
    }
    'BoostCheckRequiresMarker' = {
        $tmp = Join-Path $env:TEMP ('flux-boost-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'boost') | Out-Null
        Set-Content -Path (Join-Path $tmp 'boost\version.hpp') -Value '#define BOOST_VERSION 109000'
        $r = Invoke-Isolated "`$Flux.BoostDir = '$tmp'; if (Test-FluxBoost) { exit 0 } else { Write-Output 'half-extracted tree passes the check'; exit 1 }"
        Remove-Item $tmp -Recurse -Force
        if (-not $r.Ok) { $r.Output }
    }
    'PythonOverrideKeepsPathAndLauncher' = {
        $r = Invoke-Isolated @'
$a = Get-FluxPythonInstallOverride -LauncherPresent $false
$b = Get-FluxPythonInstallOverride -LauncherPresent $true
if ($a -notmatch 'PrependPath=0' -or $a -notmatch 'Include_launcher=1') { Write-Output "no launcher: $a"; exit 1 }
if ($b -notmatch 'PrependPath=0' -or $b -notmatch 'Include_launcher=0') { Write-Output "launcher present: $b"; exit 1 }
'@
        if (-not $r.Ok) { $r.Output }
    }
}

$failed = 0
foreach ($name in $tests.Keys) {
    $reason = & $tests[$name]
    if ($reason) { Write-Output ("FAIL {0}: {1}" -f $name, $reason); $failed++ } else { Write-Output ("PASS {0}" -f $name) }
}
Write-Output ("{0}/{1} passed" -f ($tests.Count - $failed), $tests.Count)
if ($failed) { exit 1 } else { exit 0 }
