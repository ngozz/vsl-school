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

$useCdnOn  = 'static const bool useCdn = true;'
$useCdnOff = 'static const bool useCdn = false;'

$bundledNow = $pub -match '(?m)^\s{4}- data/videos/'
"Bundled currently: $bundledNow"

if ($Bundled -ge 0) {
  if ($Bundled) {
    $pub = $pub -creplace [regex]::Escape($assetOff), $assetOn
    $cfg = $cfg -creplace [regex]::Escape($useCdnOn), $useCdnOff
    if ($Bundled -ne $bundledNow) { "Switched to FULL build (videos bundled as assets, ~3 GB)." }
  } else {
    $pub = $pub -creplace [regex]::Escape($assetOn), $assetOff
    $cfg = $cfg -creplace [regex]::Escape($useCdnOff), $useCdnOn
    if ($Bundled -ne $bundledNow) { "Switched to SMALL build (CDN mode)." }
  }
  Set-Content $pubspec -Value $pub -Encoding UTF8 -NoNewline
  Set-Content $config  -Value $cfg -Encoding UTF8 -NoNewline
  & flutter pub get | Out-Null
  "pubspec.yaml and lib/config.dart updated."
}
