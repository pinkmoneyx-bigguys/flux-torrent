# Shared settings and helpers for Flux build scripts (Windows PowerShell 5.1+).

$ErrorActionPreference = 'Stop'

$Flux = [ordered]@{
    RepoRoot      = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    QtVersion     = '6.10.1'
    QtRoot        = 'C:\Qt'
    QtArch        = 'msvc2022_64'
    VcpkgRoot     = 'C:\vcpkg'
    Triplet       = 'x64-windows-static-md-release'
    DepsRoot      = 'C:\deps'
    BoostVersion  = '1.90.0'
    LibtorrentTag = 'v2.0.11'
}
$Flux.QtPrefix         = Join-Path $Flux.QtRoot "$($Flux.QtVersion)\$($Flux.QtArch)"
$Flux.BoostDir         = Join-Path $Flux.DepsRoot ('boost_' + $Flux.BoostVersion.Replace('.', '_'))
$Flux.LibtorrentSrc    = Join-Path $Flux.DepsRoot 'src\libtorrent'
$Flux.LibtorrentPrefix = Join-Path $Flux.DepsRoot 'libtorrent'
$Flux.TripletsDir      = Join-Path $PSScriptRoot 'vcpkg-triplets'
$Flux.VcpkgToolchain   = Join-Path $Flux.VcpkgRoot 'scripts\buildsystems\vcpkg.cmake'
$Flux.VcpkgInstalled   = Join-Path $Flux.VcpkgRoot "installed\$($Flux.Triplet)"

function Get-VsWherePath {
    Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
}

function Get-VsInstallPath {
    $vswhere = Get-VsWherePath
    if (-not (Test-Path $vswhere)) { return $null }
    $path = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ([string]::IsNullOrWhiteSpace($path)) { return $null }
    return $path.Trim()
}

function ConvertTo-PathKey([string]$p) { $p.Trim().TrimEnd('\').ToLowerInvariant() }

# Make tools installed during this run visible to the current session only: append registry PATH entries
# that are missing (never drop entries, so an entered VS dev shell keeps cl.exe), then append Python 3.13's
# Scripts folder (cmake, ninja). The user's persistent PATH is never modified.
function Update-SessionPath {
    $have = @{}
    foreach ($e in ($env:Path -split ';')) { if ($e) { $have[(ConvertTo-PathKey $e)] = $true } }
    $add = @()
    foreach ($scope in 'Machine', 'User') {
        foreach ($e in ([Environment]::GetEnvironmentVariable('Path', $scope) -split ';')) {
            if ($e -and -not $have[(ConvertTo-PathKey $e)]) { $add += $e; $have[(ConvertTo-PathKey $e)] = $true }
        }
    }
    if (Get-Command py -ErrorAction SilentlyContinue) {
        $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        $scripts = (& cmd /c 'py -3.13 -c "import sysconfig; print(sysconfig.get_path(''scripts''))" 2>nul' | Out-String).Trim()
        $ErrorActionPreference = $prev
        if ($scripts -and (Test-Path $scripts) -and -not $have[(ConvertTo-PathKey $scripts)]) { $add += $scripts }
    }
    if ($add.Count) { $env:Path = ($env:Path.TrimEnd(';') + ';' + ($add -join ';')) }
}

# Python 3.13 installer options: never touch PATH (the user's default Python stays first), and install the
# py launcher only when there is none yet (scripts always call `py -3.13`).
function Get-FluxPythonInstallOverride([bool]$LauncherPresent) {
    $launcher = if ($LauncherPresent) { 'Include_launcher=0' } else { 'Include_launcher=1 InstallLauncherAllUsers=0' }
    "/quiet InstallAllUsers=0 PrependPath=0 $launcher"
}

function Test-Command([string]$name) {
    [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

# Each check returns $null when OK, or a short failure reason.
function Test-FluxMsvc { if (Get-VsInstallPath) { $null } else { 'Visual Studio 2022 C++ build tools not found' } }

function Test-FluxCMake {
    if (-not (Test-Command cmake)) { return 'cmake not on PATH' }
    $line = (& cmake --version | Select-Object -First 1)
    if ($line -match '(\d+)\.(\d+)') {
        if ([int]$Matches[1] -gt 3 -or ([int]$Matches[1] -eq 3 -and [int]$Matches[2] -ge 16)) { return $null }
    }
    "cmake too old: $line"
}

function Test-FluxNinja { if (Test-Command ninja) { $null } else { 'ninja not on PATH' } }

function Test-FluxPython313 {
    if (-not (Test-Command py)) { return 'py launcher not found' }
    $ErrorActionPreference = 'Continue'
    $v = (& cmd /c 'py -3.13 --version 2>&1' | Out-String).Trim()
    if ($v -like 'Python 3.13*') { $null } else { "py -3.13 unavailable: $v" }
}

function Test-FluxQt {
    $deploy = Join-Path $Flux.QtPrefix 'bin\windeployqt.exe'
    $quick = Join-Path $Flux.QtPrefix 'lib\cmake\Qt6Quick\Qt6QuickConfig.cmake'
    if ((Test-Path $deploy) -and (Test-Path $quick)) { $null } else { "Qt $($Flux.QtVersion) $($Flux.QtArch) not found in $($Flux.QtPrefix)" }
}

function Test-FluxOpenSsl { if (Test-Path (Join-Path $Flux.VcpkgInstalled 'include\openssl\ssl.h')) { $null } else { "openssl not installed for $($Flux.Triplet)" } }
function Test-FluxZlib { if (Test-Path (Join-Path $Flux.VcpkgInstalled 'include\zlib.h')) { $null } else { "zlib not installed for $($Flux.Triplet)" } }

function Get-FluxBoostMarker { Join-Path $Flux.BoostDir '.flux-extracted' }

function Test-FluxBoost {
    $hdr = Join-Path $Flux.BoostDir 'boost\version.hpp'
    if (-not (Test-Path $hdr)) { return "boost headers not found in $($Flux.BoostDir)" }
    # written only after a complete extraction (see setup-env.ps1), so a half-unpacked tree never passes
    if (-not (Test-Path (Get-FluxBoostMarker))) { return 'boost extraction incomplete (marker missing)' }
    if (Select-String -Path $hdr -Pattern '#define BOOST_VERSION 109000' -Quiet) { $null } else { 'boost version is not 1.90.0' }
}

function Test-FluxLibtorrent {
    $cfg = Join-Path $Flux.LibtorrentPrefix 'lib\cmake\LibtorrentRasterbar\LibtorrentRasterbarConfig.cmake'
    if (Test-Path $cfg) { $null } else { "libtorrent not installed in $($Flux.LibtorrentPrefix)" }
}

$FluxChecks = [ordered]@{
    msvc       = { Test-FluxMsvc }
    cmake      = { Test-FluxCMake }
    ninja      = { Test-FluxNinja }
    python313  = { Test-FluxPython313 }
    qt         = { Test-FluxQt }
    openssl    = { Test-FluxOpenSsl }
    zlib       = { Test-FluxZlib }
    boost      = { Test-FluxBoost }
    libtorrent = { Test-FluxLibtorrent }
}

# Enter the MSVC x64 developer environment (idempotent).
function Enter-FluxDevShell {
    if ($env:VSCMD_ARG_TGT_ARCH -eq 'x64' -and (Get-Command cl.exe -ErrorAction SilentlyContinue)) { return }
    $vs = Get-VsInstallPath
    if (-not $vs) { throw 'Visual Studio 2022 C++ build tools not found; run scripts/setup-env.ps1 first.' }
    Import-Module (Join-Path $vs 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll')
    Enter-VsDevShell -VsInstallPath $vs -DevCmdArguments '-arch=x64 -host_arch=x64' -SkipAutomaticLocation | Out-Null
}
