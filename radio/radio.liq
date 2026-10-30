settings.log.stdout := true
music = playlist(mode="randomize", reload_mode="watch", "/music")
music = crossfade(music)
radio = mksafe(music)

output.harbor(%mp3(bitrate=128), port=8000, mount="radio", radio)

key = environment.get("YT_KEY")
url = "rtmp://a.rtmp.youtube.com/live2/#{key}"

video = single("/radio/bg.png")
stream = source.mux.video(video=video, radio)

output.url(
  url=url,
  %ffmpeg(
    format="flv",
    %audio(codec="aac", b="128k"),
    %video(codec="libx264", preset="veryfast", g=50)
  ),
  stream
)