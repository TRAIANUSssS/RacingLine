param(
    [Parameter(Mandatory=$true)]
    [string]$BundlePath,

    [string]$StorageRoot = (Join-Path $env:USERPROFILE "OpenplanetNext\PluginStorage\RacingLine"),

    [string]$RangeName = "1000_1010"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $BundlePath)) {
    throw "Bundle file not found: $BundlePath"
}

$bundle = Get-Content -LiteralPath $BundlePath -Raw -Encoding UTF8 | ConvertFrom-Json
$mapName = $bundle.map.name
if ([string]::IsNullOrWhiteSpace($mapName)) {
    throw "Bundle map.name is empty: $BundlePath"
}

$invalidChars = [IO.Path]::GetInvalidFileNameChars()
$mapFolderChars = foreach ($char in $mapName.ToCharArray()) {
    if ($invalidChars -contains $char) { "_" } else { [string]$char }
}
$mapFolder = (-join $mapFolderChars).Trim()
if ([string]::IsNullOrWhiteSpace($mapFolder)) {
    throw "Bundle map.name cannot be converted to a folder name: $mapName"
}

$targetDir = Join-Path $StorageRoot (Join-Path "bundles" $mapFolder)
$targetName = "top_$RangeName.analysis_bundle.json"
$targetPath = Join-Path $targetDir $targetName

New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
Copy-Item -LiteralPath $BundlePath -Destination $targetPath -Force

Write-Host "Installed bundle:"
Write-Host $targetPath
