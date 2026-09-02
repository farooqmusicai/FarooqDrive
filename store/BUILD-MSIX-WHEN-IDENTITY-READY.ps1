$ErrorActionPreference = 'Stop'

$required = @('STORE_IDENTITY_NAME','STORE_PUBLISHER','STORE_PUBLISHER_DISPLAY_NAME')
foreach ($name in $required) {
  if (-not [Environment]::GetEnvironmentVariable($name)) {
    throw "Missing environment variable: $name"
  }
}

$assets = @('StoreLogo.png','Square150x150Logo.png','Square44x44Logo.png')
foreach ($asset in $assets) {
  if (-not (Test-Path (Join-Path $PSScriptRoot "Assets\$asset"))) {
    throw "Missing final Store asset: store\Assets\$asset"
  }
}

npm run build
npx electron-builder --dir --win --x64

$layout = Join-Path (Resolve-Path '.').Path 'release\win-unpacked'
$assetDest = Join-Path $layout 'Assets'
New-Item -ItemType Directory -Force -Path $assetDest | Out-Null
Copy-Item "$PSScriptRoot\Assets\*" $assetDest -Force

$template = Get-Content "$PSScriptRoot\Package.appxmanifest.template.xml" -Raw
$template = $template.Replace('__STORE_IDENTITY_NAME__', $env:STORE_IDENTITY_NAME)
$template = $template.Replace('__STORE_PUBLISHER__', $env:STORE_PUBLISHER)
$template = $template.Replace('__STORE_PUBLISHER_DISPLAY_NAME__', $env:STORE_PUBLISHER_DISPLAY_NAME)
$manifest = Join-Path $layout 'Package.appxmanifest.xml'
$template | Set-Content -Encoding UTF8 $manifest

New-Item -ItemType Directory -Force -Path 'release-store' | Out-Null
# Microsoft WinApp CLI packages the Electron/Win32 layout as MSIX.
npx winapp pack $layout --output '.\release-store' --manifest $manifest

Write-Host 'MSIX packaging finished. Test the package on Windows before Partner Center submission.'
