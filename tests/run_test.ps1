param(
	[Parameter(Mandatory = $true)][string]$Test
)
$godot = "C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe"
$project = "C:\Users\merli\Documents\Godot Projects\operator"
$output = & $godot --headless --path $project --script "res://tests/$Test.gd" 2>&1 | ForEach-Object { "$_" }
$code = $LASTEXITCODE
$output
$scriptErrors = @($output -match 'SCRIPT ERROR')
if ($scriptErrors.Count -gt 0) {
    Write-Host "FAILED: $Test emitted $($scriptErrors.Count) script error(s)"
    exit 1
}
if (-not ($output -match 'RESULT:')) {
    Write-Host "FAILED: $Test never printed a RESULT line"
    exit 1
}
exit $code
