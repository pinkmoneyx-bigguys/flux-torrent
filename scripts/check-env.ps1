# Verifies the Flux build toolchain. Exit code 0 when everything is present, 1 otherwise.
. (Join-Path $PSScriptRoot 'common.ps1')
Update-SessionPath

$failed = 0
foreach ($name in $FluxChecks.Keys) {
    $reason = & $FluxChecks[$name]
    if ($reason) {
        Write-Output ("FAIL {0}: {1}" -f $name, $reason)
        $failed++
    } else {
        Write-Output ("OK   {0}" -f $name)
    }
}
if ($failed -gt 0) { exit 1 }
exit 0
