# Generates data/json/videos.json — per-lesson media manifest used by the
# app's downloader (stream URLs, download-all, update-check, verification).
#
# Output shape:
# {
#   "version": "<generatedAt UTC>",
#   "totalFiles": N, "totalBytes": N,
#   "lessons": { "TOANL3KB01": [ {"n":"TOANL3KB01_01","size":123,"sha256":"..."} ] },
#   "extras":  [ {"n":"Ending","size":...,"sha256":"..."} ]
# }
#
# JSON is built with StringBuilder (ConvertTo-Json misbehaves on PS5.1 with
# nested generic lists) and written UTF-8 WITHOUT BOM, which would otherwise
# break Flutter's jsonDecode.
Set-Location $PSScriptRoot\..

$files = Get-ChildItem 'data\videos\*.mp4' | Sort-Object Name
if (-not $files) { throw 'no videos found' }

$lessons = @{}
$extras = New-Object System.Collections.Generic.List[object]
$totalBytes = [long]0

foreach ($f in $files) {
  $sha = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash.ToLower()
  $entry = @{
    n = [IO.Path]::GetFileNameWithoutExtension($f.Name)
    size = [long]$f.Length
    sha256 = "$sha"
  }
  $totalBytes += [long]$f.Length
  if ($f.BaseName -match '^((TOAN|TV)L[1-5]KB\d+)') {
    $lesson = $Matches[1]
    if (-not $lessons.ContainsKey($lesson)) {
      $lessons[$lesson] = New-Object System.Collections.Generic.List[object]
    }
    $lessons[$lesson].Add($entry) | Out-Null
  } else {
    $extras.Add($entry) | Out-Null
  }
}

$sum = ($lessons.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
$totalFiles = [int]($sum) + $extras.Count

$sb = New-Object System.Text.StringBuilder
[void]$sb.Append('{"version":"')
[void]$sb.Append((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))
[void]$sb.Append('","totalFiles":'); [void]$sb.Append($totalFiles)
[void]$sb.Append(',"totalBytes":'); [void]$sb.Append($totalBytes)
[void]$sb.Append(',"lessons":{')

$sep = ''
foreach ($k in ($lessons.Keys | Sort-Object)) {
  [void]$sb.Append($sep); $sep = ','
  [void]$sb.Append('"'); [void]$sb.Append($k); [void]$sb.Append('":[')
  $esep = ''
  foreach ($e in $lessons[$k]) {
    [void]$sb.Append($esep); $esep = ','
    [void]$sb.Append('{"n":"'); [void]$sb.Append($e.n)
    [void]$sb.Append('","size":'); [void]$sb.Append($e.size)
    [void]$sb.Append(',"sha256":"'); [void]$sb.Append($e.sha256); [void]$sb.Append('"}')
  }
  [void]$sb.Append(']')
}
[void]$sb.Append('},"extras":[')
$esep = ''
foreach ($e in $extras) {
  [void]$sb.Append($esep); $esep = ','
  [void]$sb.Append('{"n":"'); [void]$sb.Append($e.n)
  [void]$sb.Append('","size":'); [void]$sb.Append($e.size)
  [void]$sb.Append(',"sha256":"'); [void]$sb.Append($e.sha256); [void]$sb.Append('"}')
}
[void]$sb.Append(']}')

[IO.File]::WriteAllText("$PWD\data\json\videos.json", $sb.ToString(), [Text.UTF8Encoding]::new($false))
"videos.json written: $totalFiles files, $([long]($totalBytes/1MB)) MB, $($lessons.Count) lessons"
