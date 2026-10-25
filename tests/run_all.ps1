$failed = 0
Get-ChildItem tests/test_*.gd | ForEach-Object {
    Write-Host "--- $($_.BaseName)"
    & .\tests\run_test.ps1 $_.BaseName | Select-String 'RESULT'
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $($_.BaseName)"
        $failed = 1
    }
}
if ($failed -eq 0) { Write-Host 'ALL SUITES PASSED' }
exit $failed