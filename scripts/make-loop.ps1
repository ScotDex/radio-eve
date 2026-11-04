# make-loop.ps1
# Turns a raw in-game capture into a seamless, stream-ready loop.
# Usage:  .\make-loop.ps1 capture.mkv
#         .\make-loop.ps1 capture.mkv -Fps 30 -MaxRateK 4500

param(
  [Parameter(Mandatory)][string]$Path,
  [int]$Fps = 60,
  [int]$MaxRateK = 6000,
  [double]$Fade = 3
)

$full   = (Resolve-Path $Path).Path
$name   = [IO.Path]::GetFileNameWithoutExtension($full)
$out    = Join-Path (Split-Path $full) "$($name)_loop.mp4"
$dur    = [double](ffprobe -v error -show_entries format=duration -of csv=p=0 $full)
$offset = [math]::Round($dur - 2 * $Fade, 3)
$gop    = $Fps * 2

if ($dur -le (2 * $Fade + 1)) {
  Write-Error "Clip is only $dur s - too short for a $Fade s crossfade."
  exit 1
}

# Crossfade the last $Fade seconds into the first $Fade seconds so the loop seam is invisible
$filter = "[0:v]scale=-2:1080:flags=lanczos,fps=$Fps,format=yuv420p,split[a][b];" +
          "[a]trim=start=$Fade,setpts=PTS-STARTPTS[main];" +
          "[b]trim=duration=$Fade,setpts=PTS-STARTPTS[head];" +
          "[main][head]xfade=transition=fade:duration=$($Fade):offset=$offset[v]"

ffmpeg -y -i $full -filter_complex $filter -map "[v]" -an `
  -c:v libx264 -preset veryslow -tune film -crf 16 `
  -maxrate "$($MaxRateK)k" -bufsize "$($MaxRateK * 2)k" -g $gop -pix_fmt yuv420p $out

Write-Output "Done: $out ($([math]::Round($dur - $Fade, 1))s loop)"