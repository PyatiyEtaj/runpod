param(
    [string]$Directory = "datasets/flux_lora",
    [Parameter(Mandatory = $true)]
    [string]$Prefix,
    [switch]$Recurse
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path -LiteralPath $Directory
$SearchOption = if ($Recurse) { "AllDirectories" } else { "TopDirectoryOnly" }
$Line = $Prefix.Trim()

if ([string]::IsNullOrWhiteSpace($Line)) {
    throw "Prefix must not be empty."
}

$Files = [System.IO.Directory]::EnumerateFiles($Root, "*.txt", $SearchOption)
$Updated = 0
$Skipped = 0

foreach ($File in $Files) {
    $Text = [System.IO.File]::ReadAllText($File)
    $TrimmedStart = $Text.TrimStart()

    if ($TrimmedStart.StartsWith($Line)) {
        $Skipped += 1
        continue
    }

    if ([string]::IsNullOrWhiteSpace($Text)) {
        $NewText = "$Line`n"
    } else {
        $NewText = "$Line, $Text"
    }

    [System.IO.File]::WriteAllText($File, $NewText, [System.Text.UTF8Encoding]::new($false))
    $Updated += 1
}

Write-Host "Caption prefix complete."
Write-Host "Directory: $Root"
Write-Host "Updated:   $Updated"
Write-Host "Skipped:   $Skipped"
