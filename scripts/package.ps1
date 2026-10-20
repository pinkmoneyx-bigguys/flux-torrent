# Packs the deployed Flux (deploy\, made by `build.ps1 -Gui Qml -Deploy`) into dist\Flux-<version>-win64.zip,
# the file to attach to a GitHub release. Once a release tagged v<version> is published, every Flux on an
# older version offers it and installs it itself (Settings, About: "Update and restart").
param(
    [string]$Version = '',
    [string]$DeployDir = ''   # default: deploy\ in the repository
)
. (Join-Path $PSScriptRoot 'common.ps1')

$root = $Flux.RepoRoot
if ($Version -eq '') {
    $cmake = Get-Content (Join-Path $root 'src\CMakeLists.txt') -Raw
    if ($cmake -match 'set\(FLUX_VERSION "([^"]+)"') { $Version = $Matches[1] }
    else { throw 'FLUX_VERSION not found in src\CMakeLists.txt' }
}

$deploy = if ($DeployDir -ne '') { $DeployDir } else { Join-Path $root 'deploy' }
if (-not (Test-Path (Join-Path $deploy 'Flux.exe'))) {
    throw 'deploy\Flux.exe is missing: run scripts\build.ps1 -Gui Qml -Deploy first'
}

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$zip = Join-Path $dist "Flux-$Version-win64.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }

# the archive holds one folder, Flux-<version>, with the program in it
$stage = Join-Path ([System.IO.Path]::GetTempPath()) "Flux-$Version"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
Copy-Item $deploy $stage -Recurse
Compress-Archive -Path $stage -DestinationPath $zip -CompressionLevel Optimal
Remove-Item $stage -Recurse -Force

$size = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Output "Packed $zip ($size MB)"
Write-Output "Release: tag v$Version on GitHub, attach this file."
