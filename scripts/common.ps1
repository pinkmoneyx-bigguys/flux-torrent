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

# Refresh PATH from the registry so tools installed by winget in this session are visible.
function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
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

function Test-FluxBoost {
    $hdr = Join-Path $Flux.BoostDir 'boost\version.hpp'
    if (-not (Test-Path $hdr)) { return "boost headers not found in $($Flux.BoostDir)" }
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
    if ($env:VSCMD_ARG_TGT_ARCH -eq 'x64') { return }
    $vs = Get-VsInstallPath
    if (-not $vs) { throw 'Visual Studio 2022 C++ build tools not found; run scripts/setup-env.ps1 first.' }
    Import-Module (Join-Path $vs 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll')
    Enter-VsDevShell -VsInstallPath $vs -DevCmdArguments '-arch=x64 -host_arch=x64' -SkipAutomaticLocation | Out-Null
}
