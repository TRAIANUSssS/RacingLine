param(
    [Parameter(Mandatory=$true)]
    [string]$BundlePath,

    [string]$StorageRoot = (Join-Path $env:USERPROFILE "OpenplanetNext\PluginStorage\RacingLine"),

    [string]$RangeName = "1000_1010",

    [string]$BundleName = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $BundlePath)) {
    throw "Bundle file not found: $BundlePath"
}

$bundle = Get-Content -LiteralPath $BundlePath -Raw -Encoding UTF8 | ConvertFrom-Json
$mapUid = $bundle.map.uid
$mapName = $bundle.map.name
$mapKey = if (-not [string]::IsNullOrWhiteSpace($mapUid)) { $mapUid } else { $mapName }
if ([string]::IsNullOrWhiteSpace($mapKey)) {
    throw "Bundle map.uid and map.name are empty: $BundlePath"
}

$invalidChars = [IO.Path]::GetInvalidFileNameChars()
$mapFolderChars = foreach ($char in $mapKey.ToCharArray()) {
    if ($invalidChars -contains $char) { "_" } else { [string]$char }
}
$mapFolder = (-join $mapFolderChars).Trim()
if ([string]::IsNullOrWhiteSpace($mapFolder)) {
    throw "Bundle map key cannot be converted to a folder name: $mapKey"
}

$targetDir = Join-Path $StorageRoot (Join-Path "bundles" $mapFolder)
$targetName = if ([string]::IsNullOrWhiteSpace($BundleName)) {
    "top_$RangeName.analysis_bundle.json"
} else {
    $BundleName
}
$targetPath = Join-Path $targetDir $targetName

New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
Copy-Item -LiteralPath $BundlePath -Destination $targetPath -Force

Write-Host "Installed bundle:"
Write-Host $targetPath
