# Builds a Flux release into dist\, ready to attach to a GitHub release tagged v<version>:
#   Flux-<version>-setup.exe              the installer (per-user, no administrator rights; updates in place)
#   Flux-<version>-portable-win64.zip     the portable build: settings and torrents stay in its profile folder
#   SHA256SUMS.txt                        checksums of both
#   release-notes.md                      this version's section of CHANGELOG.md, with the downloads
# Every Flux already out there finds the release and offers it: an installed one takes the installer, a
# portable one the archive.
param(
    [switch]$SkipTests
)
. (Join-Path $PSScriptRoot 'common.ps1')
$ErrorActionPreference = 'Stop'

$root = $Flux.RepoRoot
$cmake = Get-Content (Join-Path $root 'src\CMakeLists.txt') -Raw -Encoding UTF8
if ($cmake -notmatch 'set\(FLUX_VERSION "([^"]+)"') { throw 'FLUX_VERSION not found in src\CMakeLists.txt' }
$version = $Matches[1]
$dist = Join-Path $root 'dist'
$stage = Join-Path $dist 'stage'
$app = Join-Path $stage "Flux-$version-portable"
Write-Host "==> Flux $version" -ForegroundColor Cyan

# 1. Build (and test), then a clean deployed copy
$buildArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'build.ps1'),
    '-Gui', 'Qml', '-Config', 'RelWithDebInfo', '-Deploy', '-DeployDir', $app)
if (-not $SkipTests) { $buildArgs += '-Test' }
& powershell @buildArgs
if ($LASTEXITCODE -ne 0) { throw "build.ps1 failed ($LASTEXITCODE)" }
# leftovers of other builds have no place in a release
Get-ChildItem $app -Filter 'qbittorrent*.exe' | Remove-Item -Force
Get-ChildItem $app -Filter '*.pdb' -Recurse | Remove-Item -Force

$installerDir = Join-Path $root 'build\src\installer'
foreach ($tool in 'fluxpack.exe', 'flux_setup_stub.exe', 'FluxSetup.exe') {
    if (-not (Test-Path (Join-Path $installerDir $tool))) { throw "$tool is missing from $installerDir" }
}

# 2. The installer: the stub with the program and the setup's interface packed after it
$setupExe = Join-Path $dist "Flux-$version-setup.exe"
Copy-Item (Join-Path $installerDir 'FluxSetup.exe') $app -Force
& (Join-Path $installerDir 'fluxpack.exe') (Join-Path $installerDir 'flux_setup_stub.exe') $app $setupExe
if ($LASTEXITCODE -ne 0) { throw "fluxpack failed ($LASTEXITCODE)" }
Remove-Item (Join-Path $app 'FluxSetup.exe') -Force

# 3. The portable build: a profile folder beside the program keeps everything there
$profileDir = Join-Path $app 'profile'
New-Item -ItemType Directory -Force $profileDir | Out-Null
Set-Content -Path (Join-Path $profileDir 'README.txt') -Encoding UTF8 -Value @(
    'Flux keeps its settings, the list of torrents and its cache in this folder (portable mode).',
    'Move the whole Flux folder to take them along; delete this folder to start from scratch.'
)
$zip = Join-Path $dist "Flux-$version-portable-win64.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($app, $zip, [System.IO.Compression.CompressionLevel]::Optimal, $true)

# 4. Checksums
$sums = foreach ($file in $setupExe, $zip) {
    '{0}  {1}' -f (Get-FileHash $file -Algorithm SHA256).Hash.ToLower(), (Split-Path $file -Leaf)
}
Set-Content -Path (Join-Path $dist 'SHA256SUMS.txt') -Value $sums -Encoding ascii

# 5. Release notes: this version's section of CHANGELOG.md, then the downloads
$changelog = Get-Content (Join-Path $root 'CHANGELOG.md') -Raw -Encoding UTF8
$section = [regex]::Match($changelog, "(?ms)^## \[?v?$([regex]::Escape($version))\]?.*?$\r?\n(.*?)(?=^## |\z)")
$notes = if ($section.Success) { $section.Groups[1].Value.Trim() } else { "Flux $version" }
$setupMb = [math]::Round((Get-Item $setupExe).Length / 1MB, 1)
$zipMb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
@"
$notes

### Downloads

| File | What it is |
|---|---|
| **Flux-$version-setup.exe** ($setupMb MB) | The installer. Installs for the current user, no administrator rights needed; later versions update in place. |
| **Flux-$version-portable-win64.zip** ($zipMb MB) | The portable build. Unpack anywhere and run ``Flux.exe``; settings and torrents stay in its ``profile`` folder. |

Windows 10 (1809 or newer) or Windows 11, 64-bit. Checksums are in ``SHA256SUMS.txt``.
"@ | Set-Content -Path (Join-Path $dist 'release-notes.md') -Encoding UTF8

Remove-Item $stage -Recurse -Force
Write-Host ''
Write-Host "==> dist\ is ready for the v$version release:" -ForegroundColor Green
Get-ChildItem $dist -File | ForEach-Object { '    {0,-38} {1,8:N1} MB' -f $_.Name, ($_.Length / 1MB) }
