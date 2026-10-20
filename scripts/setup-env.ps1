# Installs the Flux build toolchain. Idempotent: every step is skipped when its check already passes.
. (Join-Path $PSScriptRoot 'common.ps1')
Update-SessionPath

$lockFile = Join-Path $PSScriptRoot 'deps.lock'

function Write-Step([string]$msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Skip([string]$name) { Write-Host "    ${name}: уже установлено, пропускаю" -ForegroundColor DarkGray }

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Native([string]$exe, [string[]]$arguments) {
    & $exe @arguments
    if ($LASTEXITCODE -ne 0) { throw "$exe failed with exit code $LASTEXITCODE" }
}

function Install-Winget([string]$id, [string[]]$extra = @()) {
    $wargs = @('install', '-e', '--id', $id, '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity') + $extra
    & winget @wargs
    # -1978335189 = already installed / no applicable upgrade
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) { throw "winget install $id failed with exit code $LASTEXITCODE" }
    Update-SessionPath
}

function Read-Lock {
    $lock = @{}
    if (Test-Path $lockFile) {
        foreach ($line in Get-Content $lockFile) {
            if ($line -match '^\s*([^#=\s]+)\s*=\s*(.+?)\s*$') { $lock[$Matches[1]] = $Matches[2] }
        }
    }
    $lock
}

# 1. Visual Studio Build Tools
Write-Step 'MSVC (Visual Studio 2022 Build Tools)'
if (Test-FluxMsvc) {
    if (-not (Test-IsAdmin)) { throw 'Запустите от имени администратора: нужна установка Visual Studio Build Tools' }
    Install-Winget 'Microsoft.VisualStudio.2022.BuildTools' @('--override', '--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --passive --wait')
} else { Write-Skip 'msvc' }

# 2. Python 3.13 (per-user, no admin), then CMake and Ninja from PyPI into its Scripts folder
Write-Step 'Python 3.13, CMake, Ninja'
if (Test-FluxPython313) {
    $override = Get-FluxPythonInstallOverride -LauncherPresent ([bool](Get-Command py -ErrorAction SilentlyContinue))
    Install-Winget 'Python.Python.3.13' @('--scope', 'user', '--override', $override)
} else { Write-Skip 'python313' }
if ((Test-FluxCMake) -or (Test-FluxNinja)) {
    # cmake/ninja land in Python 3.13's Scripts folder; Update-SessionPath puts it on this session's PATH only
    Invoke-Native 'py' @('-3.13', '-m', 'pip', 'install', '--upgrade', '--quiet', 'cmake>=3.27,<4', 'ninja')
    Update-SessionPath
} else { Write-Skip 'cmake, ninja' }
foreach ($check in 'cmake', 'ninja', 'python313') {
    $reason = & $FluxChecks[$check]
    if ($reason) { throw "$check still missing after install: $reason (откройте новое окно PowerShell и запустите скрипт снова)" }
}

# 3. Qt
Write-Step "Qt $($Flux.QtVersion) $($Flux.QtArch)"
if (Test-FluxQt) {
    Invoke-Native 'py' @('-3.13', '-m', 'pip', 'install', '--upgrade', '--quiet', 'aqtinstall')
    # download.qt.io is unreachable from some regions: use an official mirror with per-archive .sha1 checks
    Invoke-Native 'py' @('-3.13', '-m', 'aqt', '-c', (Join-Path $PSScriptRoot 'aqt-settings.ini'),
        'install-qt', 'windows', 'desktop', $Flux.QtVersion, "win64_$($Flux.QtArch)",
        '-m', 'qtimageformats', 'qtshadertools', '-O', $Flux.QtRoot, '-b', 'https://mirrors.dotsrc.org/qtproject')
} else { Write-Skip 'qt' }

# 4. vcpkg + openssl + zlib
Write-Step 'vcpkg, OpenSSL, zlib'
$lock = Read-Lock
if (-not (Test-Path (Join-Path $Flux.VcpkgRoot '.git'))) {
    Invoke-Native 'git' @('clone', 'https://github.com/microsoft/vcpkg', $Flux.VcpkgRoot)
}
if (-not $lock.ContainsKey('vcpkg_commit')) {
    $tag = (& git -C $Flux.VcpkgRoot describe --tags --abbrev=0 origin/master).Trim()
    $lock['vcpkg_commit'] = (& git -C $Flux.VcpkgRoot rev-list -n 1 $tag).Trim()
    $lock['vcpkg_tag'] = $tag
}
$current = (& git -C $Flux.VcpkgRoot rev-parse HEAD).Trim()
if ($current -ne $lock['vcpkg_commit']) {
    Invoke-Native 'git' @('-C', $Flux.VcpkgRoot, 'fetch', '--quiet', 'origin')
    Invoke-Native 'git' @('-C', $Flux.VcpkgRoot, 'checkout', '--quiet', $lock['vcpkg_commit'])
}
if (-not (Test-Path (Join-Path $Flux.VcpkgRoot 'vcpkg.exe')) -or $current -ne $lock['vcpkg_commit']) {
    Invoke-Native (Join-Path $Flux.VcpkgRoot 'bootstrap-vcpkg.bat') @('-disableMetrics')
}
if ((Test-FluxOpenSsl) -or (Test-FluxZlib)) {
    # Some machines pin GitHub hosts (codeload.github.com) to a wrong IP in the hosts file. When vcpkg's
    # download fails, fetch the archive into vcpkg's download cache ourselves, resolving the host via a
    # public resolver for this one request only; vcpkg still verifies the file's SHA512.
    $vcpkgExe = Join-Path $Flux.VcpkgRoot 'vcpkg.exe'
    $downloads = Join-Path $Flux.VcpkgRoot 'downloads'
    $ErrorActionPreference = 'Continue'  # vcpkg writes progress to stderr; failures are checked via exit codes
    for ($round = 1; $round -le 5; $round++) {
        $out = & $vcpkgExe install openssl zlib --triplet $Flux.Triplet "--overlay-triplets=$($Flux.TripletsDir)" 2>&1 | Out-String
        Write-Host $out
        if ($LASTEXITCODE -eq 0) { break }
        $m = [regex]::Match($out, 'Downloading (https://\S+) -> (\S+)')
        if (-not $m.Success -or $round -eq 5) { throw 'vcpkg install openssl zlib failed' }
        $url = $m.Groups[1].Value
        $target = Join-Path $downloads $m.Groups[2].Value
        $final = $url
        $hdr = & curl.exe -sSI -L --max-time 30 $url 2>$null
        foreach ($line in $hdr) { if ($line -match '^location:\s*(\S+)') { $final = $Matches[1] } }
        $hostName = ([Uri]$final).Host
        $ip = (Resolve-DnsName $hostName -Server 1.1.1.1 -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress
        Write-Host "    vcpkg download failed; fetching $final via $ip"
        & curl.exe -fsSL --max-time 600 --resolve "${hostName}:443:${ip}" -o "$target.part" $final
        if ($LASTEXITCODE -ne 0) { throw "download of $final failed" }
        Move-Item "$target.part" $target -Force
    }
    $ErrorActionPreference = 'Stop'
} else { Write-Skip 'openssl, zlib' }

# 5. Boost headers
Write-Step "Boost $($Flux.BoostVersion) (headers)"
if (Test-FluxBoost) {
    $dl = Join-Path $Flux.DepsRoot 'dl'
    New-Item -ItemType Directory -Force -Path $dl | Out-Null
    $name = 'boost_' + $Flux.BoostVersion.Replace('.', '_') + '.tar.gz'
    $archive = Join-Path $dl $name
    $url = "https://archives.boost.io/release/$($Flux.BoostVersion)/source/$name"
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        if (-not (Test-Path $archive)) {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
        }
        # Windows' built-in tar (libarchive); only the headers are needed. Unpack into a staging folder and
        # move it into place, then write the marker, so an interrupted run never leaves a "valid" half tree.
        $stage = Join-Path $Flux.DepsRoot 'boost.staging'
        if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $stage | Out-Null
        $leaf = Split-Path $Flux.BoostDir -Leaf
        & "$env:SystemRoot\System32\tar.exe" -xzf $archive -C $stage "$leaf/boost"
        if ($LASTEXITCODE -eq 0) {
            if (Test-Path $Flux.BoostDir) { Remove-Item $Flux.BoostDir -Recurse -Force }
            Move-Item (Join-Path $stage $leaf) $Flux.BoostDir
            Remove-Item $stage -Recurse -Force
            Set-Content -Path (Get-FluxBoostMarker) -Value $Flux.BoostVersion -Encoding ASCII
            break
        }
        Remove-Item $archive -Force
        if ($attempt -eq 2) { throw "Не удалось распаковать $name" }
    }
} else { Write-Skip 'boost' }

# 6. libtorrent
Write-Step "libtorrent $($Flux.LibtorrentTag)"
if (Test-FluxLibtorrent) {
    Enter-FluxDevShell
    if (-not (Test-Path (Join-Path $Flux.LibtorrentSrc '.git'))) {
        Invoke-Native 'git' @('clone', '--recurse-submodules', '--branch', $Flux.LibtorrentTag, 'https://github.com/arvidn/libtorrent', $Flux.LibtorrentSrc)
    }
    $bld = Join-Path $Flux.LibtorrentSrc 'build'
    Invoke-Native 'cmake' @('-S', $Flux.LibtorrentSrc, '-B', $bld, '-G', 'Ninja',
        '-DCMAKE_BUILD_TYPE=Release', '-DCMAKE_CXX_STANDARD=20', '-DBUILD_SHARED_LIBS=OFF',
        '-Ddeprecated-functions=OFF', '-Dstatic_runtime=OFF',
        "-DCMAKE_INSTALL_PREFIX=$($Flux.LibtorrentPrefix)", "-DBOOST_ROOT=$($Flux.BoostDir)",
        "-DCMAKE_TOOLCHAIN_FILE=$($Flux.VcpkgToolchain)", "-DVCPKG_TARGET_TRIPLET=$($Flux.Triplet)",
        "-DVCPKG_OVERLAY_TRIPLETS=$($Flux.TripletsDir)")
    Invoke-Native 'cmake' @('--build', $bld, '--target', 'install')
} else { Write-Skip 'libtorrent' }

# 7. libmpv (built-in player)
Write-Step "libmpv $($Flux.MpvRelease)"
if (Test-FluxMpv) {
    New-Item -ItemType Directory -Force -Path $Flux.MpvDir | Out-Null
    if (-not (Test-Path (Join-Path $Flux.MpvDir 'libmpv-2.dll'))) {
        $dl = Join-Path $Flux.DepsRoot 'dl'
        New-Item -ItemType Directory -Force -Path $dl | Out-Null
        $archive = Join-Path $dl $Flux.MpvPackage
        if (-not (Test-Path $archive)) {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri "https://github.com/shinchiro/mpv-winbuild-cmake/releases/download/$($Flux.MpvRelease)/$($Flux.MpvPackage)" -OutFile $archive -UseBasicParsing
        }
        # Windows 11 tar (libarchive) reads 7z
        & "$env:SystemRoot\System32\tar.exe" -xf $archive -C $Flux.MpvDir
        if ($LASTEXITCODE -ne 0) { throw "Не удалось распаковать $($Flux.MpvPackage)" }
        Set-Content -Path (Join-Path $Flux.MpvDir 'VERSION.txt') -Value "$($Flux.MpvPackage -replace '\.7z$', '') (shinchiro/mpv-winbuild-cmake release $($Flux.MpvRelease))" -Encoding ASCII
    }
    Enter-FluxDevShell
    New-FluxMpvImportLib
} else { Write-Skip 'libmpv' }

# 8. Lock file
$lock['qt'] = $Flux.QtVersion
$lock['boost'] = $Flux.BoostVersion
$lock['libtorrent'] = $Flux.LibtorrentTag
$lock['triplet'] = $Flux.Triplet
$lock['mpv'] = $Flux.MpvPackage
$lines = @('# Pinned dependency versions for Flux. Written by scripts/setup-env.ps1.')
foreach ($k in ($lock.Keys | Sort-Object)) { $lines += "$k = $($lock[$k])" }
Set-Content -Path $lockFile -Value $lines -Encoding ASCII

Write-Step 'Готово. Проверка окружения:'
& (Join-Path $PSScriptRoot 'check-env.ps1')
exit $LASTEXITCODE
