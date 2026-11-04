# make-mix.ps1
# Builds one loudness-normalised, shuffled mix.m4a from a folder of tracks.
# Usage:  .\make-mix.ps1                       (uses the current folder)
#         .\make-mix.ps1 -Folder C:\path\to\tracks
#
# Folder layout it creates/uses:
#   <Folder>\*.m4a|*.mp3|*.flac   source tracks
#   <Folder>\wav\                 converted WAVs (reused on later runs)
#   <Folder>\wav\rejects\         move WAVs here to exclude them for good
#   <Folder>\mix.m4a              the output

param(
  [string]$Folder = (Get-Location).Path,
  [int]$BitrateK = 192
)

Push-Location $Folder
try {
  New-Item -ItemType Directory -Force wav, wav\rejects | Out-Null

  # 1. Convert any new tracks to identical, normalised WAVs (skips done/rejected ones)
  Get-ChildItem *.m4a, *.mp3, *.flac -File | ForEach-Object {
    $clean = ($_.BaseName -replace "'", "" -replace '[^\x00-\x7F]', '-')
    $out   = "wav\$clean.wav"
    if (-not (Test-Path $out) -and -not (Test-Path "wav\rejects\$clean.wav")) {
      Write-Output "Converting: $($_.Name)"
      ffmpeg -y -loglevel error -i $_.FullName -af "loudnorm=I=-16:TP=-1.5" -ar 44100 -ac 2 -c:a pcm_s16le $out
    }
  }

  # 2. Shuffle into a concat list
  $tracks = Get-ChildItem wav\*.wav
  if ($tracks.Count -eq 0) { throw "No WAVs found in $Folder\wav" }
  $tracks | Get-Random -Count $tracks.Count |
    ForEach-Object { "file '$($_.Name)'" } |
    Set-Content wav\list.txt -Encoding ascii

  # 3. Join and encode once
  ffmpeg -y -f concat -safe 0 -i wav\list.txt -c:a aac -b:a "$($BitrateK)k" mix.m4a

  $len = [double](ffprobe -v error -show_entries format=duration -of csv=p=0 mix.m4a)
  Write-Output ("Done: {0}\mix.m4a - {1} tracks, {2:N1} hours" -f $Folder, $tracks.Count, ($len / 3600))
}
finally {
  Pop-Location
}