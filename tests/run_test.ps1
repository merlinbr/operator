param(
	[Parameter(Mandatory = $true)][string]$Test
)
$godot = "C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe"
$project = "C:\Users\merli\Documents\Godot Projects\operator"
& $godot --headless --path $project --script "res://tests/$Test.gd"
exit $LASTEXITCODE
