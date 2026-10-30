# Toggles whether data/videos is bundled as app assets.
#   .\toggle_videos.ps1            -> show current state
#   .\toggle_videos.ps1 -Bundled $false  -> small APK (CDN mode)
#   .\toggle_videos.ps1 -Bundled $true   -> full APK (assets bundled)
# Syncs pubspec.yaml assets AND lib/config.dart CdnConfig.videosBundled.
param([int]$Bundled = -1)

Set-Location $PSScriptRoot\..

$pubspec = 'pubspec.yaml'
$config  = 'lib\config.dart'

$pub = Get-Content $pubspec -Raw
$cfg = Get-Content $config -Raw

$assetOn  = '    - data/videos/'
$assetOff = '    # - data/videos/   # excluded: CDN mode (run tools\toggle_videos.ps1 -Bundled $true to include)'

$bundledNow = $pub -match '(?m)^\s{4}- data/videos/'
"Bundled currently: $bundledNow"

if ($Bundled -ge 0) {
  if ($Bundled -eq $bundledNow) {
    "No change needed."
    exit 0
  }
  if ($Bundled) {
    $pub = $pub -creplace [regex]::Escape($assetOff), $assetOn
    $cfg = $cfg -creplace 'static const bool videosBundled = false;', 'static const bool videosBundled = true;'
    "Switched to FULL build (videos bundled as assets)."
  } else {
    $pub = $pub -creplace [regex]::Escape($assetOn), $assetOff
    $cfg = $cfg -creplace 'static const bool videosBundled = true;', 'static const bool videosBundled = false;'
    "Switched to SMALL build (videos served from CDN / downloads)."
  }
  Set-Content $pubspec -Value $pub -Encoding UTF8 -NoNewline
  Set-Content $config  -Value $cfg -Encoding UTF8 -NoNewline
  & flutter pub get | Out-Null
  "pubspec.yaml and lib/config.dart updated."
}
