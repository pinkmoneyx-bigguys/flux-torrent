# Configures and builds the fork. Flags mirror .github/workflows/ci_windows.yaml at release-5.2.4.
param(
    [ValidateSet('Widgets', 'Qml')] [string]$Gui = 'Widgets',
    [ValidateSet('RelWithDebInfo', 'Release', 'Debug')] [string]$Config = 'RelWithDebInfo',
    [switch]$Test,
    [switch]$GuiTests,   # with -Test: also run the tests labelled `gui` (they open real windows)
    [switch]$Deploy
)
. (Join-Path $PSScriptRoot 'common.ps1')
Update-SessionPath

& (Join-Path $PSScriptRoot 'check-env.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Enter-FluxDevShell
Set-Location $Flux.RepoRoot
# Test executables load Qt DLLs at run time (CI's install-qt-action does the same)
$env:Path = (Join-Path $Flux.QtPrefix 'bin') + ';' + $env:Path

function Invoke-Native([string]$exe, [string[]]$arguments) {
    & $exe @arguments
    if ($LASTEXITCODE -ne 0) { throw "$exe $($arguments -join ' ') failed with exit code $LASTEXITCODE" }
}

$guiFlags = switch ($Gui) {
    'Widgets' { @('-DGUI=ON') }
    'Qml'     { @('-DGUI=OFF', '-DQML_GUI=ON') }
}
$exeName = if ($Gui -eq 'Qml') { 'Flux.exe' } else { 'qbittorrent.exe' }

Invoke-Native 'cmake' (@('-S', '.', '-B', 'build', '-G', 'Ninja',
    "-DCMAKE_BUILD_TYPE=$Config",
    '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON',
    "-DCMAKE_PREFIX_PATH=$($Flux.QtPrefix)",
    "-DCMAKE_TOOLCHAIN_FILE=$($Flux.VcpkgToolchain)",
    "-DVCPKG_TARGET_TRIPLET=$($Flux.Triplet)",
    "-DVCPKG_OVERLAY_TRIPLETS=$($Flux.TripletsDir)",
    "-DBOOST_ROOT=$($Flux.BoostDir)",
    "-DLibtorrentRasterbar_DIR=$(Join-Path $Flux.LibtorrentPrefix 'lib\cmake\LibtorrentRasterbar')",
    '-DMSVC_RUNTIME_DYNAMIC=ON',
    '-DWEBUI=ON',
    ('-DTESTING=' + $(if ($Test) { 'ON' } else { 'OFF' }))) + $guiFlags)

Invoke-Native 'cmake' @('--build', 'build')

if ($Test) {
    # Same as upstream's `check` target (ctest --output-on-failure), minus documented known failures
    $known = @(Get-Content (Join-Path $PSScriptRoot 'known-test-failures.txt') |
        Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object { $_.Trim() })
    # Tests labelled `gui` open real windows on the desktop; they only run on request
    $labelArgs = if ($GuiTests) { @() } else { @('-LE', 'gui') }
    $ctestArgs = @('--test-dir', 'build\test', '--output-on-failure', '--no-tests=error') + $labelArgs
    if ($known.Count -gt 0) { $ctestArgs += @('-E', ('^(' + ($known -join '|') + ')$')) }
    Invoke-Native 'ctest' $ctestArgs
    if ($known.Count -gt 0) {
        & ctest --test-dir build\test --no-tests=error @labelArgs -R ('^(' + ($known -join '|') + ')$') | Out-Null
        $state = if ($LASTEXITCODE -eq 0) { 'now PASS - remove them from known-test-failures.txt' } else { 'still fail (see known-test-failures.txt)' }
        Write-Warning ("Known failures excluded: {0} - {1}" -f ($known -join ', '), $state)
    }
}

if ($Deploy) {
    $deployDir = Join-Path $Flux.RepoRoot 'deploy'
    New-Item -ItemType Directory -Force -Path $deployDir | Out-Null
    Copy-Item (Join-Path 'build' $exeName) $deployDir -Force
    $deployArgs = @('--release', '--no-translations', (Join-Path $deployDir $exeName))
    if ($Gui -eq 'Qml') { $deployArgs = @('--qmldir', (Join-Path $Flux.RepoRoot 'src\qmlgui\qml')) + $deployArgs }
    Invoke-Native (Join-Path $Flux.QtPrefix 'bin\windeployqt.exe') $deployArgs
}
